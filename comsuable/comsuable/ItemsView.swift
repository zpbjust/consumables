import SwiftUI
import UIKit

struct ItemsView: View {
    @EnvironmentObject private var store: PassportStore
    @State private var query = ""
    @State private var category: ItemCategory?
    @State private var room = ""
    @State private var showingAdd = false
    @State private var selectedItemDetail: ItemDetailRoute?
    @State private var showsCompactTitle = false

    private var filtered: [ConsumableItem] {
        store.items.filter { item in
            item.matches(query) && (category == nil || item.category == category) &&
            (room.isEmpty || item.room == room)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                NavigationStack {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            VStack(alignment: .leading, spacing: 8) {
                                PassportPageTitle(title: "Items")
                                Text("Exact parts, sizes, and locations")
                                    .foregroundStyle(PassportTheme.muted)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 12)

                            Section {
                                itemResults
                                    .padding(.horizontal, 20)
                                    .padding(.top, 18)
                                    .padding(.bottom, 70)
                            } header: {
                                stickyFilters
                            }
                        }
                        .passportContentWidth()
                    }
                    .background(PassportTheme.canvas)
                    .scrollDismissesKeyboard(.interactively)
                    .coordinateSpace(name: PassportPageTitleCoordinateSpace.name)
                    .onPreferenceChange(PassportPageTitleBottomKey.self) { titleBottom in
                        let nextValue = PassportPinnedTitleVisibility.next(
                            current: showsCompactTitle,
                            titleBottom: titleBottom
                        )
                        if nextValue != showsCompactTitle {
                            showsCompactTitle = nextValue
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .safeAreaInset(edge: .bottom) {
                        HStack {
                            Spacer()
                            PassportFloatingButton(title: "Add item") { showingAdd = true }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                    .fullScreenCover(isPresented: $showingAdd) { ItemEditorView() }
                    .fullScreenCover(item: $selectedItemDetail) { route in
                        ItemDetailScreen(itemID: route.id)
                    }
                }

                Rectangle()
                    .fill(PassportTheme.canvas)
                    .frame(height: geometry.safeAreaInsets.top)
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .zIndex(100)
            }
        }
        .tint(PassportTheme.teal)
    }

    private var stickyFilters: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Text("Items")
                    .font(.headline)
                    .foregroundStyle(PassportTheme.ink)
                    .frame(maxWidth: .infinity)
                    .opacity(showsCompactTitle ? 1 : 0)
                    .accessibilityHidden(!showsCompactTitle)
                    .accessibilityAddTraits(.isHeader)

                HStack {
                    SectionEyebrow(title: "\(filtered.count) items")
                    Spacer()
                }
                .opacity(showsCompactTitle ? 0 : 1)
                .accessibilityHidden(showsCompactTitle)
            }
            .frame(height: 32)
            .animation(.easeOut(duration: 0.12), value: showsCompactTitle)

            PassportSearchField(placeholder: "Search model, size, or room", text: $query)
                .accessibilityIdentifier("itemSearchField")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("All", selected: category == nil) { category = nil }
                    ForEach(ItemCategory.allCases) { option in
                        filterChip(option.displayName, selected: category == option) { category = option }
                    }
                }
            }

            if !store.items.isEmpty {
                Menu {
                    Button("All rooms") { room = "" }
                    ForEach(Array(Set(store.items.map(\.room))).sorted(), id: \.self) { option in
                        Button(option) { room = option }
                    }
                } label: {
                    Text(room.isEmpty ? "All rooms" : room)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PassportTheme.teal)
                        .frame(minHeight: 28)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .background {
            if showsCompactTitle {
                PassportTheme.canvas.ignoresSafeArea(edges: .top)
            } else {
                PassportTheme.canvas
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PassportTheme.line)
                .frame(height: 0.5)
        }
        .accessibilityIdentifier("itemsStickyFilters")
        .zIndex(1)
    }

    @ViewBuilder
    private var itemResults: some View {
        if filtered.isEmpty {
            PassportCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(store.items.isEmpty ? "No items saved yet" : "No items match")
                        .font(.title3.weight(.bold))
                    Text(store.items.isEmpty
                         ? "Add the first replacement you want to remember."
                         : "Try another model, category, or room.")
                        .foregroundStyle(PassportTheme.muted)
                    if store.items.isEmpty {
                        Button("Add an item") { showingAdd = true }
                            .buttonStyle(PassportPrimaryButton())
                    }
                }
            }
        } else {
            LazyVStack(spacing: 10) {
                ForEach(filtered) { item in
                    Button {
                        selectedItemDetail = ItemDetailRoute(id: item.id)
                    } label: {
                        PassportCard {
                            ItemRow(item: item)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .foregroundStyle(selected ? .white : PassportTheme.teal)
                .background(selected ? PassportTheme.teal : PassportTheme.pale, in: Capsule())
        }
    }
}

struct ItemDetailRoute: Identifiable {
    let id: UUID
}

struct ItemDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    let itemID: UUID

    var body: some View {
        NavigationStack {
            ItemDetailView(itemID: itemID)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                    }
                }
        }
        .tint(PassportTheme.teal)
    }
}

struct ItemDetailView: View {
    @EnvironmentObject private var store: PassportStore
    @Environment(\.dismiss) private var dismiss
    let itemID: UUID
    @State private var showingEdit = false
    @State private var showingReplace = false
    @State private var showingDelete = false
    @State private var showingAdded = false
    @State private var operationError: String?

    var body: some View {
        Group {
            if let item = store.item(id: itemID) {
                detail(item)
            } else {
                Text("Item not found")
                    .foregroundStyle(PassportTheme.muted)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
        .fullScreenCover(isPresented: $showingEdit) {
            if let item = store.item(id: itemID) { ItemEditorView(item: item) }
        }
        .fullScreenCover(isPresented: $showingReplace) { ReplacementView(itemID: itemID) }
        .confirmationDialog("Delete this item?", isPresented: $showingDelete) {
            Button("Delete item", role: .destructive) {
                if store.deleteItem(id: itemID) {
                    dismiss()
                } else {
                    operationError = store.lastSaveError ?? "The item couldn't be deleted."
                }
            }
        } message: { Text("Its photo and replacement history will be removed from this device.") }
        .alert("Added to shopping", isPresented: $showingAdded) {
            Button("OK", role: .cancel) { }
        }
        .alert("Changes not saved", isPresented: Binding(
            get: { operationError != nil },
            set: { if !$0 { operationError = nil } }
        )) {
            Button("OK", role: .cancel) { operationError = nil }
        } message: { Text(operationError ?? "Please try again.") }
        .tint(PassportTheme.teal)
    }

    private func detail(_ item: ConsumableItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PassportCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 15) {
                            ItemArtwork(item: item, photo: store.photo(for: item), size: 88)
                            VStack(alignment: .leading, spacing: 5) {
                                SectionEyebrow(title: item.category.displayName)
                                Text(item.name)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(PassportTheme.ink)
                                Text([item.brand, item.model].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.subheadline)
                                    .foregroundStyle(PassportTheme.muted)
                                ReplacementDueStatus(item: item)
                            }
                        }
                        Button("Mark as replaced") { showingReplace = true }
                            .buttonStyle(PassportPrimaryButton())
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionEyebrow(title: "What to buy")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        detailMetric("Size", item.size.isEmpty ? "Not added" : item.size)
                        detailMetric("Stock at home", "\(item.stockOnHand) remaining")
                        detailMetric("Preferred store", item.preferredStore.isEmpty ? "Not added" : item.preferredStore)
                        detailMetric("Typical price", formattedPrice(item.typicalPrice))
                    }
                    HStack(spacing: 12) {
                        Button("Add to shopping list") {
                            if store.addToShopping(itemID: item.id) {
                                showingAdded = true
                            } else {
                                operationError = store.lastSaveError ?? "The item couldn't be added to Shopping."
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        if let url = normalizedProductURL(item.productURL) {
                            Link("Open product link", destination: url)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionEyebrow(title: "Location")
                    PassportCard {
                        HStack(spacing: 12) {
                            Image("EditorLocation")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: 3) {
                                Text([store.home(id: item.homeID)?.name, item.room]
                                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(PassportTheme.ink)
                                Text(item.location.isEmpty ? "No exact spot added" : item.location)
                                    .font(.caption)
                                    .foregroundStyle(PassportTheme.muted)
                            }
                        }
                    }
                }

                if item.nextDueDate != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionEyebrow(title: "Replacement schedule")
                        PassportCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    ReplacementDueStatus(item: item)
                                    Spacer()
                                    Text("Every \(item.intervalDays ?? 0) days")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PassportTheme.teal)
                                }
                                Text(item.remindersEnabled ? "Reminder is on" : "Reminder is off")
                                    .font(.caption)
                                    .foregroundStyle(PassportTheme.muted)
                                if let average = item.averageReplacementDays {
                                    Text("Your observed average is \(average) days.")
                                        .font(.caption)
                                        .foregroundStyle(PassportTheme.muted)
                                }
                            }
                        }
                    }
                }

                if !item.notes.isEmpty {
                    PassportCard {
                        VStack(alignment: .leading, spacing: 5) {
                            SectionEyebrow(title: "Notes")
                            Text(item.notes).foregroundStyle(PassportTheme.ink)
                        }
                    }
                }

                if !item.history.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionEyebrow(title: "Replacement history")
                        PassportCard {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(item.history) { record in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(record.date, format: .dateTime.month().day().year())
                                            .font(.subheadline.weight(.semibold))
                                        Text("\(record.quantity) replaced" +
                                             (record.store.isEmpty ? "" : " · \(record.store)"))
                                            .font(.caption)
                                            .foregroundStyle(PassportTheme.muted)
                                        if !record.note.isEmpty { Text(record.note).font(.caption) }
                                    }
                                    if record.id != item.history.last?.id { Divider() }
                                }
                            }
                        }
                    }
                }
                Button("Delete item", role: .destructive) { showingDelete = true }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(20)
            .passportContentWidth()
        }
        .background(PassportTheme.canvas)
        .scrollDismissesKeyboard(.interactively)
    }

    private func detailMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(PassportTheme.muted)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PassportTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(PassportTheme.pale, in: RoundedRectangle(cornerRadius: 15))
    }

    private func formattedPrice(_ price: Decimal?) -> String {
        guard let price else { return "Not added" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        return formatter.string(from: NSDecimalNumber(decimal: price)) ?? NSDecimalNumber(decimal: price).stringValue
    }

    private func normalizedProductURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        return URL(string: "https://\(trimmed)")
    }

}

struct ReplacementView: View {
    @EnvironmentObject private var store: PassportStore
    @Environment(\.dismiss) private var dismiss
    let itemID: UUID
    @State private var date = Date()
    @State private var quantity = 1
    @State private var price = ""
    @State private var retailer = ""
    @State private var note = ""
    @State private var showingSaveError = false

    var body: some View {
        NavigationStack {
            Form {
                if let item = store.item(id: itemID) {
                    Section("Inventory") {
                        LabeledContent("Currently on hand", value: "\(item.stockOnHand)")
                        Text(quantity > item.stockOnHand
                             ? "Saving records the replacement. Stock will remain at 0 because there are not enough units marked on hand."
                             : "Saving uses \(quantity) from stock and updates the next due date.")
                            .font(.caption)
                            .foregroundStyle(PassportTheme.muted)
                    }
                }
                Section("Replacement") {
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...100)
                    TextField("Store (optional)", text: $retailer)
                    TextField("Total price (optional)", text: $price)
                        .keyboardType(.decimalPad)
                    TextField("Note (optional)", text: $note, axis: .vertical)
                }
                if let item = store.item(id: itemID), let days = item.intervalDays,
                   let next = Calendar.current.date(byAdding: .day, value: days, to: date) {
                    Section("Next due") { Text(next, format: .dateTime.month(.wide).day().year()) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PassportTheme.canvas)
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                guard retailer.isEmpty, let item = store.item(id: itemID) else { return }
                retailer = item.preferredStore
            }
            .navigationTitle("Record replacement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let saved = store.recordReplacement(itemID: itemID, record: ReplacementRecord(
                            date: date, quantity: quantity, price: Decimal(string: price),
                            store: retailer, note: note
                        ))
                        if saved { dismiss() } else { showingSaveError = true }
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    PassportKeyboardDoneButton()
                }
            }
            .alert("Replacement not saved", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(store.lastSaveError ?? "Choose today or an earlier date and try again.")
            }
        }
        .tint(PassportTheme.teal)
    }
}
