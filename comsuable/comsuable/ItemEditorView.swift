import PhotosUI
import SwiftUI
import Vision

struct ItemEditorView: View {
    private enum FocusedField: Hashable {
        case model
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PassportStore
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @State private var draft: ConsumableItem
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var showingCamera = false
    @State private var pendingCameraScanImage: UIImage?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var scanResult: LabelScanResult?
    @State private var showingScanFailure = false
    @State private var isScanning = false
    @State private var showingPaywall = false
    @State private var isCheckingAccess = false
    @State private var shouldFocusModelAfterScan = false
    @State private var typicalPriceText: String
    @FocusState private var focusedField: FocusedField?

    private let isEditing: Bool

    init(item: ConsumableItem? = nil) {
        isEditing = item != nil
        _draft = State(initialValue: item ?? ConsumableItem(
            name: "", category: .hvac, brand: "", model: "", size: "",
            homeID: UUID(), room: "", location: "", notes: "",
            lastReplaced: nil, intervalDays: nil, remindersEnabled: false
        ))
        _typicalPriceText = State(initialValue: item?.typicalPrice.map {
            NSDecimalNumber(decimal: $0).stringValue
        } ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    labelCard
                    detailsCard
                    locationCard
                    replacementCard
                    buyingCard
                    notesCard
                }
                .padding(20)
                .padding(.bottom, 76)
                .passportContentWidth()
            }
            .background(PassportTheme.canvas)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit item" : "Add item")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button(isCheckingAccess ? "Checking…" : "Save item") { save() }
                    .buttonStyle(PassportPrimaryButton())
                    .disabled(!canSave || isCheckingAccess)
                    .opacity(canSave && !isCheckingAccess ? 1 : 0.5)
                    .accessibilityIdentifier("saveItemButton")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    PassportKeyboardDoneButton()
                }
            }
            .onAppear {
                if !store.homes.contains(where: { $0.id == draft.homeID }), let first = store.homes.first {
                    draft.homeID = first.id
                }
                if draft.room.isEmpty {
                    draft.room = store.home(id: draft.homeID)?.rooms.first ?? ""
                }
            }
            .onChange(of: draft.homeID) { newID in
                if !(store.home(id: newID)?.rooms.contains(draft.room) ?? false) { draft.room = "" }
            }
            .onChange(of: selectedPhoto) { newPhoto in
                Task {
                    guard let bytes = try? await newPhoto?.loadTransferable(type: Data.self),
                          let image = UIImage(data: bytes) else { return }
                    photo = image
                    await recognize(image)
                }
            }
            .onChange(of: showingScanFailure) { isShowing in
                if !isShowing { focusModelAfterScanIfNeeded() }
            }
            .sheet(isPresented: $showingCamera, onDismiss: scanPendingCameraImage) {
                CameraPicker { image in
                    photo = image
                    pendingCameraScanImage = image
                }
            }
            .fullScreenCover(item: $scanResult, onDismiss: focusModelAfterScanIfNeeded) { result in
                LabelScanReviewView(
                    result: result,
                    onApply: applyScannedDetails,
                    onManualEntry: { shouldFocusModelAfterScan = true }
                )
            }
            .alert("No readable label found", isPresented: $showingScanFailure) {
                Button("Enter manually") {
                    shouldFocusModelAfterScan = true
                }
                Button("Try another photo", role: .cancel) { }
            } message: {
                Text("Use a sharp, well-lit photo with the label filling most of the frame.")
            }
            .alert("Couldn't save item", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: { Text(errorMessage) }
            .fullScreenCover(isPresented: $showingPaywall, onDismiss: finishPendingSave) {
                PaywallView(reason: .itemLimit)
            }
        }
        .tint(PassportTheme.teal)
    }

    private var labelCard: some View {
        PassportCard {
            VStack(alignment: .leading, spacing: 14) {
                EditorSectionTitle(asset: "EditorScan", title: "Identify this item")
                HStack(alignment: .top, spacing: 14) {
                    Group {
                        if let image = photo ?? store.photo(for: draft) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            VStack(spacing: 8) {
                                Image("EditorScan")
                                    .renderingMode(.original)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 42, height: 42)
                                Text("Product label")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(PassportTheme.muted)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(PassportTheme.pale)
                        }
                    }
                    .frame(width: 132, height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                    VStack(spacing: 10) {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            EditorActionButton(
                                asset: "EditorScan",
                                title: isScanning ? "Reading label…" : "Scan a label",
                                filled: true
                            ) {
                                if !isScanning { showingCamera = true }
                            }
                            .disabled(isScanning)
                        }
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            EditorActionLabel(
                                asset: "EditorPhoto",
                                title: photo == nil && draft.imageFilename == nil ? "Choose photo" : "Change photo",
                                filled: !UIImagePickerController.isSourceTypeAvailable(.camera)
                            )
                        }
                        .disabled(isScanning)
                    }
                }
                if isScanning { ProgressView().tint(PassportTheme.teal) }
                Text("Photo and recognized text stay on this device. Review every suggestion before applying it.")
                    .font(.caption)
                    .foregroundStyle(PassportTheme.muted)
            }
        }
    }

    private var detailsCard: some View {
        PassportCard {
            VStack(alignment: .leading, spacing: 13) {
                EditorSectionTitle(asset: "EditorDetails", title: "Item details")
                EditorTextField(title: "Name", placeholder: draft.category.exampleName, text: $draft.name)
                    .accessibilityIdentifier("itemNameField")
                Divider()
                Picker("Category", selection: $draft.category) {
                    ForEach(ItemCategory.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                Divider()
                EditorTextField(title: "Brand", placeholder: "Filtrete", text: $draft.brand)
                Divider()
                VStack(alignment: .leading, spacing: 5) {
                    Text("Model number").font(.caption).foregroundStyle(PassportTheme.muted)
                    TextField("MPR-1000", text: $draft.model)
                        .textInputAutocapitalization(.characters)
                        .font(.body.weight(.semibold))
                        .accessibilityIdentifier("itemModelField")
                        .focused($focusedField, equals: .model)
                }
                Divider()
                EditorTextField(title: "Size or specification", placeholder: "16 × 25 × 1", text: $draft.size)
            }
        }
    }

    private var locationCard: some View {
        PassportCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    EditorSectionTitle(asset: "EditorLocation", title: "Where it lives")
                    Spacer()
                    if !LocationPresentation.showsHomePicker(homeCount: store.homes.count),
                       let homeName = store.home(id: draft.homeID)?.name {
                        Text(homeName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PassportTheme.muted)
                    }
                }
                if LocationPresentation.showsHomePicker(homeCount: store.homes.count) {
                    Picker("Home", selection: $draft.homeID) {
                        ForEach(store.homes) { home in Text(home.name).tag(home.id) }
                    }
                    Divider()
                }
                Picker("Room", selection: $draft.room) {
                    Text("Choose a room").tag("")
                    ForEach(store.home(id: draft.homeID)?.rooms ?? [], id: \.self) { room in
                        Text(room).tag(room)
                    }
                }
                .accessibilityIdentifier("itemRoomPicker")
                Divider()
                EditorTextField(
                    title: "Exact location",
                    placeholder: "Hallway ceiling vent (optional)",
                    text: $draft.location
                )
                Text("Add or rename rooms from Settings › Homes & rooms.")
                    .font(.caption)
                    .foregroundStyle(PassportTheme.muted)
            }
        }
    }

    private var replacementCard: some View {
        PassportCard {
            VStack(alignment: .leading, spacing: 13) {
                EditorSectionTitle(asset: "EditorPlan", title: "Replacement schedule")
                Toggle("Replace on a schedule", isOn: Binding(
                    get: { draft.intervalDays != nil },
                    set: { enabled in
                        draft.intervalDays = enabled ? (draft.intervalDays ?? 90) : nil
                        if enabled && draft.lastReplaced == nil { draft.lastReplaced = Date() }
                        if !enabled { draft.remindersEnabled = false }
                    }
                ))
                Text("Use the last replacement date and interval to calculate the next due date and reminder.")
                    .font(.caption)
                    .foregroundStyle(PassportTheme.muted)
                if draft.intervalDays != nil {
                    Divider()
                    DatePicker("Last replaced", selection: Binding(
                        get: { draft.lastReplaced ?? Date() },
                        set: { draft.lastReplaced = $0 }
                    ), in: ...Date(), displayedComponents: .date)
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Replace every")
                            .font(.caption)
                            .foregroundStyle(PassportTheme.muted)
                        HStack(spacing: 7) {
                            schedulePreset("30 days", days: 30)
                            schedulePreset("3 months", days: 90)
                            schedulePreset("6 months", days: 180)
                            schedulePreset("1 year", days: 365)
                        }
                        Stepper("Custom: \(draft.intervalDays ?? 90) days", value: Binding(
                            get: { draft.intervalDays ?? 90 },
                            set: { draft.intervalDays = $0 }
                        ), in: 1...730)
                    }
                    if let dueDate = draft.nextDueDate {
                        Text("Next due \(dueDate.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PassportTheme.amber)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PassportTheme.pale, in: RoundedRectangle(cornerRadius: 12))
                    }
                    Toggle("Notify me before it is due", isOn: $draft.remindersEnabled)
                }
            }
        }
    }

    private func schedulePreset(_ title: String, days: Int) -> some View {
        Button {
            draft.intervalDays = days
        } label: {
            Text(title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .foregroundStyle(draft.intervalDays == days ? .white : PassportTheme.teal)
                .background(
                    draft.intervalDays == days ? PassportTheme.teal : PassportTheme.pale,
                    in: RoundedRectangle(cornerRadius: 10)
                )
        }
        .buttonStyle(.plain)
    }

    private var buyingCard: some View {
        PassportCard {
            VStack(alignment: .leading, spacing: 13) {
                EditorSectionTitle(asset: "TabShoppingSelected", title: "Buying details")
                Text("Optional details make the shopping list useful at the store.")
                    .font(.caption)
                    .foregroundStyle(PassportTheme.muted)
                Stepper("Stock at home: \(draft.stockOnHand)", value: $draft.stockOnHand, in: 0...99)
                Divider()
                EditorTextField(title: "Preferred store", placeholder: "Home Depot", text: $draft.preferredStore)
                Divider()
                VStack(alignment: .leading, spacing: 5) {
                    Text("Typical price")
                        .font(.caption)
                        .foregroundStyle(PassportTheme.muted)
                    TextField("18.99", text: $typicalPriceText)
                        .keyboardType(.decimalPad)
                        .font(.body.weight(.semibold))
                }
                Divider()
                VStack(alignment: .leading, spacing: 5) {
                    Text("Product link")
                        .font(.caption)
                        .foregroundStyle(PassportTheme.muted)
                    TextField("https://…", text: $draft.productURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.weight(.semibold))
                }
            }
        }
    }

    private var notesCard: some View {
        PassportCard {
            VStack(alignment: .leading, spacing: 10) {
                EditorSectionTitle(asset: "EditorNotes", title: "Notes")
                TextField("Anything helpful for next time", text: $draft.notes, axis: .vertical)
                    .lineLimit(2...5)
            }
        }
    }

    private var canSave: Bool {
        let hasName = !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasIdentifier = !draft.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !draft.size.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasName && hasIdentifier && !draft.room.isEmpty
    }

    private func save() {
        draft.typicalPrice = Decimal(string: typicalPriceText.trimmingCharacters(in: .whitespacesAndNewlines))
        Task {
            isCheckingAccess = true
            await purchaseManager.ensureAccessResolved()
            isCheckingAccess = false
            if !isEditing && !PremiumAccessPolicy.canCreateItem(
                existingItemCount: store.items.count,
                isPro: purchaseManager.isPro
            ) {
                showingPaywall = true
                return
            }
            saveItemNow()
        }
    }

    private func finishPendingSave() {
        if purchaseManager.isPro { saveItemNow() }
    }

    private func saveItemNow() {
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.model = draft.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard store.saveItem(draft, image: photo) else {
            errorMessage = store.lastSaveError ?? "Please try again."
            showingError = true
            return
        }
        if draft.remindersEnabled {
            Task { _ = try? await ReminderService.requestAuthorization() }
        }
        dismiss()
    }

    private func recognize(_ image: UIImage) async {
        guard let cgImage = image.cgImage else { return }
        isScanning = true
        let lines = await Task.detached(priority: .userInitiated) { () -> [String] in
            let request = LabelTextRecognition.makeRequest()
            do {
                try VNImageRequestHandler(cgImage: cgImage).perform([request])
                return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            } catch { return [] }
        }.value
        isScanning = false
        var seen = Set<String>()
        let uniqueLines = lines.filter { seen.insert($0).inserted }
        if uniqueLines.isEmpty {
            showingScanFailure = true
        } else {
            scanResult = LabelScanParser.parse(lines: uniqueLines)
        }
    }

    private func focusModelAfterScanIfNeeded() {
        guard shouldFocusModelAfterScan else { return }
        shouldFocusModelAfterScan = false
        focusedField = .model
    }

    private func scanPendingCameraImage() {
        guard let image = pendingCameraScanImage else { return }
        pendingCameraScanImage = nil
        Task { await recognize(image) }
    }

    private func applyScannedDetails(_ result: LabelScanResult) {
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.name = result.suggestedName
        }
        if !result.brand.isEmpty { draft.brand = result.brand }
        if !result.model.isEmpty { draft.model = result.model }
        if !result.size.isEmpty { draft.size = result.size }
        if let category = result.category { draft.category = category }
    }
}

private struct EditorSectionTitle: View {
    let asset: String
    let title: String

    var body: some View {
        HStack(spacing: 9) {
            Image(asset)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 25, height: 25)
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(PassportTheme.ink)
        }
    }
}

private struct EditorTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(PassportTheme.muted)
            TextField(placeholder, text: $text)
                .font(.body.weight(.semibold))
        }
    }
}

private struct EditorActionLabel: View {
    let asset: String
    let title: String
    let filled: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(asset)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 21, height: 21)
                .padding(4)
                .background(filled ? Color.white.opacity(0.94) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
            Text(title)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(filled ? Color.white : PassportTheme.teal)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(filled ? PassportTheme.teal : PassportTheme.pale, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct EditorActionButton: View {
    let asset: String
    let title: String
    let filled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            EditorActionLabel(asset: asset, title: title, filled: filled)
        }
        .buttonStyle(.plain)
    }
}

private struct LabelScanReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var result: LabelScanResult
    @State private var showingRawText = false
    let onApply: (LabelScanResult) -> Void
    let onManualEntry: () -> Void

    init(
        result: LabelScanResult,
        onApply: @escaping (LabelScanResult) -> Void,
        onManualEntry: @escaping () -> Void
    ) {
        _result = State(initialValue: result)
        self.onApply = onApply
        self.onManualEntry = onManualEntry
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PassportCard {
                        VStack(alignment: .leading, spacing: 8) {
                            EditorSectionTitle(asset: "EditorScan", title: "Review scanned details")
                            Text("We found \(result.lines.count) lines on the label. Check each suggestion before applying it.")
                                .font(.subheadline)
                                .foregroundStyle(PassportTheme.muted)
                        }
                    }

                    PassportCard {
                        VStack(alignment: .leading, spacing: 13) {
                            EditorTextField(
                                title: "Suggested name",
                                placeholder: "Enter a name",
                                text: $result.suggestedName
                            )
                            Divider()
                            EditorTextField(title: "Brand", placeholder: "Not found", text: $result.brand)
                            Divider()
                            EditorTextField(title: "Model number", placeholder: "Not found", text: $result.model)
                            Divider()
                            EditorTextField(title: "Size or specification", placeholder: "Not found", text: $result.size)
                            Divider()
                            Picker("Category", selection: $result.category) {
                                Text("Not sure").tag(nil as ItemCategory?)
                                ForEach(ItemCategory.allCases) { category in
                                    Text(category.displayName).tag(category as ItemCategory?)
                                }
                            }
                        }
                    }

                    PassportCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Button(showingRawText ? "Hide recognized text" : "Show all recognized text") {
                                showingRawText.toggle()
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PassportTheme.teal)
                            if showingRawText {
                                ForEach(result.lines, id: \.self) { line in
                                    Text(line)
                                        .font(.subheadline)
                                        .textSelection(.enabled)
                                    if line != result.lines.last { Divider() }
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 76)
                .passportContentWidth()
            }
            .background(PassportTheme.canvas)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Review label")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Apply details") {
                    onApply(result)
                    dismiss()
                }
                .buttonStyle(PassportPrimaryButton())
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enter manually") {
                        onManualEntry()
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    PassportKeyboardDoneButton()
                }
            }
        }
        .tint(PassportTheme.teal)
    }
}

enum LabelTextRecognition {
    nonisolated static func makeRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        request.usesLanguageCorrection = true
        return request
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) { }
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
