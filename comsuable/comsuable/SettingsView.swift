import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var showingPaywall = false
    @State private var selectedDestination: SettingsDestination?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PassportPageTitle(title: "Settings")

                    membershipCard

                    settingsSection("Home") {
                        Button { selectedDestination = .homes } label: {
                            settingsRow("Homes & rooms", detail: "Organize items by space")
                        }
                        .buttonStyle(.plain)
                        Divider()
                        Button { selectedDestination = .notifications } label: {
                            settingsRow("Notifications", detail: "Due-date reminder timing")
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection("Data") {
                        Button { selectedDestination = .data } label: {
                            settingsRow("Backup, restore & export", detail: "Keep a copy of your records")
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection("Support") {
                        Button { selectedDestination = .howItWorks } label: {
                            settingsRow("How Home Passport works", detail: "Items, schedules, and shopping")
                        }
                        .buttonStyle(.plain)
                        Divider()
                        Button { selectedDestination = .privacy } label: {
                            settingsRow("Privacy", detail: "On-device by design")
                        }
                        .buttonStyle(.plain)
                        Divider()
                        Button { selectedDestination = .about } label: {
                            settingsRow("About", detail: "Version \(appVersion)")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .passportContentWidth()
            }
            .background(PassportTheme.canvas)
            .scrollDismissesKeyboard(.interactively)
            .passportCollapsingTitle("Settings")
            .fullScreenCover(isPresented: $showingPaywall) {
                PaywallView(reason: .settings)
            }
            .fullScreenCover(item: $selectedDestination) { destination in
                SettingsDetailScreen(destination: destination)
            }
        }
        .tint(PassportTheme.teal)
    }

    @ViewBuilder
    private var membershipCard: some View {
        let content = PassportCard {
            HStack(spacing: 14) {
                Image("ProPassportHero")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Home Passport Pro")
                        .font(.headline)
                        .foregroundStyle(PassportTheme.ink)
                    Text(membershipDetail)
                        .font(.caption)
                        .foregroundStyle(PassportTheme.muted)
                }
                Spacer()
                Text(purchaseManager.isPro ? "ACTIVE" : "VIEW")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(PassportTheme.teal)
            }
        }

        if PurchaseConfiguration.isReady && !purchaseManager.isPro {
            Button { showingPaywall = true } label: { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(title: title)
            PassportCard { VStack(spacing: 0) { content() } }
        }
    }

    private func settingsRow(_ title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PassportTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(PassportTheme.muted)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var membershipDetail: String {
        if !PurchaseConfiguration.isReady {
            return "All features are available while purchases are being configured"
        }
        return purchaseManager.isPro
            ? "Lifetime unlock active"
            : "Unlimited items and multiple homes"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

private enum SettingsDestination: String, Identifiable {
    case homes
    case notifications
    case data
    case howItWorks
    case privacy
    case about

    var id: String { rawValue }
}

private struct SettingsDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    let destination: SettingsDestination

    var body: some View {
        NavigationStack {
            destinationView
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
        .tint(PassportTheme.teal)
    }

    @ViewBuilder
    private var destinationView: some View {
        switch destination {
        case .homes:
            HomesView()
        case .notifications:
            NotificationSettingsView()
        case .data:
            DataSettingsView()
        case .howItWorks:
            HowItWorksView()
        case .privacy:
            PrivacyDetailsView()
        case .about:
            AboutHomePassportView()
        }
    }
}

private struct NotificationSettingsView: View {
    @EnvironmentObject private var store: PassportStore
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var alertMessage: String?
    @State private var permissionState: NotificationPermissionState?
    @State private var isRequestingPermission = false

    var body: some View {
        Form {
            Section("Reminder timing") {
                Picker("Notify me", selection: Binding(
                    get: { store.reminderLeadDays },
                    set: { if !store.setReminderLeadDays($0) { alertMessage = store.lastSaveError } }
                )) {
                    Text("On the due date").tag(0)
                    Text("3 days before").tag(3)
                    Text("1 week before").tag(7)
                    Text("2 weeks before").tag(14)
                }
            }
            Section {
                LabeledContent("Permission", value: permissionState?.displayName ?? "Checking…")

                switch permissionState {
                case .notRequested:
                    Button(isRequestingPermission ? "Requesting…" : "Allow notifications") {
                        requestNotificationPermission()
                    }
                    .disabled(isRequestingPermission)
                case .denied:
                    Button("Open iOS Settings") {
                        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(settingsURL)
                    }
                case .allowed:
                    Text("Home Passport can deliver reminders for items that have notifications enabled.")
                        .font(.caption)
                        .foregroundStyle(PassportTheme.muted)
                case nil:
                    ProgressView()
                }
            } header: {
                Text("Notification access")
            } footer: {
                Text("Only items with a replacement schedule and reminders enabled create a notification.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(PassportTheme.canvas)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshPermissionState() }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await refreshPermissionState() }
        }
        .alert("Home Passport", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: { Text(alertMessage ?? "") }
    }

    private func requestNotificationPermission() {
        Task {
            isRequestingPermission = true
            defer { isRequestingPermission = false }
            do {
                let state = try await ReminderService.requestAuthorization()
                permissionState = state
                alertMessage = state == .allowed
                    ? "Notifications are enabled. Reminders will be scheduled for eligible items."
                    : "Notifications are off. You can enable them later in iOS Settings."
            } catch {
                await refreshPermissionState()
                alertMessage = "Notification permission couldn't be requested. Please try again or check iOS Settings."
            }
        }
    }

    private func refreshPermissionState() async {
        permissionState = await ReminderService.authorizationState()
    }
}

private struct DataSettingsView: View {
    @EnvironmentObject private var store: PassportStore
    @State private var showingImport = false
    @State private var showingImportConfirm = false
    @State private var pendingImportURL: URL?
    @State private var backupURL: URL?
    @State private var historyURL: URL?
    @State private var alertMessage: String?

    var body: some View {
        Form {
            Section("Backup") {
                Button("Prepare full backup") {
                    do { backupURL = try store.exportData() }
                    catch { alertMessage = "The backup couldn't be prepared. Check available storage and try again." }
                }
                if let backupURL {
                    ShareLink(item: backupURL) { Text("Share backup file") }
                }
                Button("Import backup") { showingImport = true }
            }
            Section("Replacement history") {
                Button("Prepare CSV export") {
                    do { historyURL = try store.exportReplacementHistory() }
                    catch { alertMessage = "The replacement history couldn't be prepared." }
                }
                if let historyURL {
                    ShareLink(item: historyURL) { Text("Share history CSV") }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PassportTheme.canvas)
        .navigationTitle("Backup & export")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showingImport, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                pendingImportURL = url
                showingImportConfirm = true
            case .failure:
                alertMessage = "The backup file couldn't be opened."
            }
        }
        .confirmationDialog("Replace current records?", isPresented: $showingImportConfirm) {
            Button("Import and replace", role: .destructive) {
                guard let url = pendingImportURL else { return }
                do { try store.importData(from: url) }
                catch { alertMessage = error.localizedDescription }
                pendingImportURL = nil
            }
            Button("Cancel", role: .cancel) { pendingImportURL = nil }
        } message: {
            Text("Current homes, items, shopping entries, and photos will be replaced by the backup.")
        }
        .alert("Home Passport", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: { Text(alertMessage ?? "") }
    }
}

private struct HowItWorksView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                helpCard("1. Save the exact item", "Scan a label or enter the model and size manually. Add the room and exact installation spot.", asset: "EditorScan")
                helpCard("2. Set a replacement schedule", "Choose the last replacement date and a repeat interval. Schedule collects everything that is due.", asset: "EditorPlan")
                helpCard("3. Shop with confidence", "Keep stock, store, price, and product-link details with the item, then add it to Shopping when needed.", asset: "TabShoppingSelected")
                helpCard("4. Record the replacement", "Mark the item as replaced to update its history, stock, next due date, and observed cadence.", asset: "EditorDetails")
            }
            .padding(20)
            .passportContentWidth()
        }
        .background(PassportTheme.canvas)
        .navigationTitle("How it works")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func helpCard(_ title: String, _ copy: String, asset: String) -> some View {
        PassportCard {
            HStack(alignment: .top, spacing: 14) {
                Image(asset)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.headline).foregroundStyle(PassportTheme.ink)
                    Text(copy).font(.subheadline).foregroundStyle(PassportTheme.muted)
                }
            }
        }
    }
}

private struct PrivacyDetailsView: View {
    var body: some View {
        List {
            Section("On this device") {
                LabeledContent("Account", value: "Not required")
                LabeledContent("Items and photos", value: "Stored locally")
                LabeledContent("Label recognition", value: "Processed locally")
            }
            Section {
                Text("A backup leaves the app only when you choose to share it. Product links open in your browser when selected.")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AboutHomePassportView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                LabeledContent("Storage", value: "On device")
            }
            Section {
                Text("Home Passport keeps the exact replacement details, schedule, and history for the everyday parts your home depends on.")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HomesView: View {
    @EnvironmentObject private var store: PassportStore
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var showingAdd = false
    @State private var showingPaywall = false
    @State private var isCheckingAccess = false

    var body: some View {
        List {
            ForEach(store.homes) { home in
                NavigationLink {
                    HomeRoomsView(homeID: home.id)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(home.name)
                        Text("\(store.items.filter { $0.homeID == home.id }.count) items")
                            .font(.caption)
                            .foregroundStyle(PassportTheme.muted)
                    }
                }
            }
        }
        .navigationTitle("Homes")
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button(isCheckingAccess ? "Checking…" : "Add home") { addHomeTapped() }
                .disabled(isCheckingAccess)
        } }
        .fullScreenCover(isPresented: $showingAdd) {
            NameEntryView(title: "New home", fieldTitle: "Home name", initialValue: "") { value in
                store.addHome(name: value)
            }
        }
        .fullScreenCover(isPresented: $showingPaywall, onDismiss: {
            if purchaseManager.isPro { showingAdd = true }
        }) {
            PaywallView(reason: .homeLimit)
        }
    }

    private func addHomeTapped() {
        Task {
            isCheckingAccess = true
            await purchaseManager.ensureAccessResolved()
            isCheckingAccess = false
            if PremiumAccessPolicy.canCreateHome(
                existingHomeCount: store.homes.count,
                isPro: purchaseManager.isPro
            ) {
                showingAdd = true
            } else {
                showingPaywall = true
            }
        }
    }
}

private struct HomeRoomsView: View {
    @EnvironmentObject private var store: PassportStore
    @Environment(\.dismiss) private var dismiss
    let homeID: UUID
    @State private var showingAddRoom = false
    @State private var showingDelete = false
    @State private var cannotDelete = false
    @State private var homeName = ""
    @State private var roomToRename: String?
    @State private var cannotDeleteRoom = false
    @State private var couldNotSave = false

    var body: some View {
        List {
            if let home = store.home(id: homeID) {
                Section("Home name") {
                    TextField("Home name", text: $homeName)
                    Button("Save home name") {
                        if !store.renameHome(id: homeID, name: homeName) { couldNotSave = true }
                    }
                    .disabled(homeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || homeName == home.name)
                }
                Section("Rooms") {
                    ForEach(home.rooms, id: \.self) { room in
                        Text(room)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    if !store.deleteRoom(room, homeID: homeID) {
                                        cannotDeleteRoom = true
                                    }
                                }
                                Button("Rename") {
                                    roomToRename = room
                                }
                                .tint(PassportTheme.teal)
                            }
                    }
                    Button("Add room") { showingAddRoom = true }
                }
                if store.homes.count > 1 {
                    Section {
                        Button("Delete home", role: .destructive) {
                            if store.items.contains(where: { $0.homeID == homeID }) { cannotDelete = true }
                            else { showingDelete = true }
                        }
                    } footer: {
                        Text("Move or delete this home's items before deleting the home.")
                    }
                }
            }
        }
        .navigationTitle(store.home(id: homeID)?.name ?? "Home")
        .scrollDismissesKeyboard(.interactively)
        .onAppear { homeName = store.home(id: homeID)?.name ?? "" }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                PassportKeyboardDoneButton()
            }
        }
        .fullScreenCover(isPresented: $showingAddRoom) {
            NameEntryView(title: "Add room", fieldTitle: "Room name", initialValue: "") { value in
                store.addRoom(value, homeID: homeID)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { roomToRename != nil },
            set: { if !$0 { roomToRename = nil } }
        )) {
            if let roomToRename {
                NameEntryView(title: "Rename room", fieldTitle: "Room name", initialValue: roomToRename) { value in
                    store.renameRoom(roomToRename, to: value, homeID: homeID)
                }
            }
        }
        .alert("Room can't be deleted", isPresented: $cannotDeleteRoom) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Keep at least one room and move this room's items before deleting it.")
        }
        .alert("Home contains items", isPresented: $cannotDelete) {
            Button("OK", role: .cancel) { }
        } message: { Text("Move or delete those items first.") }
        .alert("Home name not saved", isPresented: $couldNotSave) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(store.lastSaveError ?? "Use a valid name and try again.")
        }
        .confirmationDialog("Delete this home?", isPresented: $showingDelete) {
            Button("Delete home", role: .destructive) {
                if store.deleteHome(id: homeID) {
                    dismiss()
                } else {
                    couldNotSave = true
                }
            }
        }
    }
}

private struct NameEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let fieldTitle: String
    let onSave: (String) -> Bool
    @State private var value: String
    @State private var showingSaveError = false

    init(title: String, fieldTitle: String, initialValue: String, onSave: @escaping (String) -> Bool) {
        self.title = title
        self.fieldTitle = fieldTitle
        self.onSave = onSave
        _value = State(initialValue: initialValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                PassportCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(fieldTitle)
                            .font(.caption)
                            .foregroundStyle(PassportTheme.muted)
                        TextField(fieldTitle, text: $value)
                            .textInputAutocapitalization(.words)
                            .font(.body.weight(.semibold))
                            .submitLabel(.done)
                            .onSubmit(save)
                    }
                }
                .padding(20)
                .passportContentWidth()
            }
            .background(PassportTheme.canvas)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(cleanValue.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    PassportKeyboardDoneButton()
                }
            }
            .alert("Name not saved", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Use a different name and try again. Names in the same home must be unique.")
            }
        }
        .tint(PassportTheme.teal)
    }

    private var cleanValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !cleanValue.isEmpty else { return }
        if onSave(cleanValue) {
            dismiss()
        } else {
            showingSaveError = true
        }
    }
}
