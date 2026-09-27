import SwiftUI
import UIKit

struct ShoppingView: View {
    @EnvironmentObject private var store: PassportStore
    @State private var showingAdd = false
    @State private var showingStoreMode = false
    @State private var selectedItemDetail: ItemDetailRoute?
    @State private var operationError: String?

    private var active: [ShoppingEntry] { store.shopping.filter { !$0.isPurchased } }
    private var purchased: [ShoppingEntry] { store.shopping.filter(\.isPurchased) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PassportPageTitle(title: "Shopping")

                    Text("The exact details, ready at the store.")
                        .foregroundStyle(PassportTheme.muted)

                    if active.isEmpty && purchased.isEmpty {
                        PassportCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Your list is clear")
                                    .font(.title3.weight(.bold))
                                Text("Add a saved item when it's time to buy a replacement.")
                                    .foregroundStyle(PassportTheme.muted)
                            }
                        }
                    }

                    if !active.isEmpty {
                        Button("Start shopping") { showingStoreMode = true }
                            .buttonStyle(PassportPrimaryButton())
                        SectionEyebrow(title: "To buy · \(active.count)")
                        entries(active)
                    }
                    if !purchased.isEmpty {
                        SectionEyebrow(title: "Purchased")
                        entries(purchased)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 70)
                .passportContentWidth()
            }
            .background(PassportTheme.canvas)
            .passportCollapsingTitle("Shopping")
            .safeAreaInset(edge: .bottom) {
                if !store.items.isEmpty {
                    HStack {
                        Spacer()
                        PassportFloatingButton(title: "Add to list") { showingAdd = true }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
            .fullScreenCover(isPresented: $showingAdd) { AddShoppingView() }
            .fullScreenCover(isPresented: $showingStoreMode) { StoreModeView() }
            .fullScreenCover(item: $selectedItemDetail) { route in
                ItemDetailScreen(itemID: route.id)
            }
            .alert("Shopping list not updated", isPresented: Binding(
                get: { operationError != nil },
                set: { if !$0 { operationError = nil } }
            )) {
                Button("OK", role: .cancel) { operationError = nil }
            } message: { Text(operationError ?? "Please try again.") }
        }
        .tint(PassportTheme.teal)
    }

    private func entries(_ entries: [ShoppingEntry]) -> some View {
        LazyVStack(spacing: 10) {
            ForEach(entries) { entry in
                if let item = store.item(id: entry.itemID) {
                    PassportCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                ItemArtwork(item: item, photo: store.photo(for: item), size: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.subheadline.weight(.semibold))
                                    Text([item.model, item.size].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(PassportTheme.muted)
                                }
                                Spacer()
                                Text("To buy: \(entry.quantity)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PassportTheme.teal)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(PassportTheme.pale, in: Capsule())
                            }
                            if !entry.preferredStore.isEmpty {
                                Text("Preferred store: \(entry.preferredStore)")
                                    .font(.caption)
                                    .foregroundStyle(PassportTheme.muted)
                            }
                            Text(entry.isPurchased
                                 ? "Added to stock · \(item.stockOnHand) at home"
                                 : "Stock at home: \(item.stockOnHand)")
                                .font(.caption)
                                .foregroundStyle(entry.isPurchased ? PassportTheme.teal : PassportTheme.muted)
                            HStack(spacing: 18) {
                                if !entry.isPurchased {
                                    Button("Bought · add to stock") {
                                        if !store.markPurchased(entryID: entry.id) {
                                            operationError = store.lastSaveError ?? "The purchase couldn't be saved."
                                        }
                                    }
                                } else {
                                    Button("View item") {
                                        selectedItemDetail = ItemDetailRoute(id: item.id)
                                    }
                                }
                                Button("Remove", role: .destructive) {
                                    if !store.removeShopping(entryID: entry.id) {
                                        operationError = store.lastSaveError ?? "The shopping item couldn't be removed."
                                    }
                                }
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }
                }
            }
        }
    }
}

enum ShoppingItemSelection {
    static func filteredItems(_ items: [ConsumableItem], query: String) -> [ConsumableItem] {
        items
            .filter { $0.matches(query) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func activeQuantity(for itemID: UUID, entries: [ShoppingEntry]) -> Int? {
        entries.first { $0.itemID == itemID && !$0.isPurchased }?.quantity
    }
}

private struct AddShoppingView: View {
    @EnvironmentObject private var store: PassportStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredItems: [ConsumableItem] {
        ShoppingItemSelection.filteredItems(store.items, query: query)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("Choose a saved item, then set how many you need.")
                        .foregroundStyle(PassportTheme.muted)

                    PassportSearchField(
                        placeholder: "Search name, model, size, or room",
                        text: $query
                    )
                    .accessibilityIdentifier("shoppingItemSearchField")

                    SectionEyebrow(title: "\(filteredItems.count) items")

                    if filteredItems.isEmpty {
                        PassportCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No matching items")
                                    .font(.headline)
                                    .foregroundStyle(PassportTheme.ink)
                                Text("Try another name, model, size, or room.")
                                    .font(.subheadline)
                                    .foregroundStyle(PassportTheme.muted)
                            }
                        }
                    } else {
                        ForEach(filteredItems) { item in
                            NavigationLink {
                                AddShoppingConfigurationView(itemID: item.id) {
                                    dismiss()
                                }
                            } label: {
                                shoppingItemRow(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 24)
                .passportContentWidth()
            }
            .background(PassportTheme.canvas)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Choose item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    PassportKeyboardDoneButton()
                }
            }
        }
        .tint(PassportTheme.teal)
    }

    private func shoppingItemRow(_ item: ConsumableItem) -> some View {
        PassportCard {
            HStack(spacing: 14) {
                ItemArtwork(item: item, photo: store.photo(for: item), size: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundStyle(PassportTheme.ink)
                        .lineLimit(2)

                    let productDetails = [item.brand, item.model].filter { !$0.isEmpty }
                    if !productDetails.isEmpty {
                        Text(productDetails.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(PassportTheme.muted)
                            .lineLimit(1)
                    }

                    let locationDetails = [item.size, item.room].filter { !$0.isEmpty }
                    if !locationDetails.isEmpty {
                        Text(locationDetails.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(PassportTheme.muted)
                            .lineLimit(1)
                    }

                    if let activeQuantity = ShoppingItemSelection.activeQuantity(
                        for: item.id,
                        entries: store.shopping
                    ) {
                        Text("Already on list · Qty \(activeQuantity)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PassportTheme.teal)
                    }
                }

                Spacer(minLength: 8)

                Text("Choose")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PassportTheme.teal)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("shoppingItem_\(item.id.uuidString)")
    }
}

private struct AddShoppingConfigurationView: View {
    @EnvironmentObject private var store: PassportStore
    let itemID: UUID
    let onAdded: () -> Void
    @State private var quantity = 1
    @State private var preferredStore = ""
    @State private var didLoadDefaults = false
    @State private var showingSaveError = false

    private var item: ConsumableItem? { store.item(id: itemID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let item {
                    PassportCard {
                        HStack(spacing: 14) {
                            ItemArtwork(item: item, photo: store.photo(for: item), size: 72)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(PassportTheme.ink)
                                Text([item.brand, item.model].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.subheadline)
                                    .foregroundStyle(PassportTheme.muted)
                                Text([item.size, item.room].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(PassportTheme.muted)
                            }
                        }
                    }

                    if let activeQuantity = ShoppingItemSelection.activeQuantity(
                        for: item.id,
                        entries: store.shopping
                    ) {
                        Text("This item is already on your list with quantity \(activeQuantity). Adding will increase that quantity.")
                            .font(.subheadline)
                            .foregroundStyle(PassportTheme.teal)
                            .padding(.horizontal, 4)
                    }

                    PassportCard {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Quantity")
                                    .font(.headline)
                                    .foregroundStyle(PassportTheme.ink)
                                Stepper("Add \(quantity)", value: $quantity, in: 1...100)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Preferred store")
                                    .font(.headline)
                                    .foregroundStyle(PassportTheme.ink)
                                TextField("Optional", text: $preferredStore)
                                    .textInputAutocapitalization(.words)
                                    .padding(.horizontal, 14)
                                    .frame(height: 48)
                                    .background(PassportTheme.canvas, in: RoundedRectangle(cornerRadius: 14))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(PassportTheme.line, lineWidth: 1)
                                    }
                            }
                        }
                    }
                } else {
                    PassportCard {
                        Text("This item is no longer available.")
                            .foregroundStyle(PassportTheme.muted)
                    }
                }
            }
            .padding(20)
            .passportContentWidth()
        }
        .background(PassportTheme.canvas)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Add to shopping")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button(actionTitle) {
                if store.addToShopping(itemID: itemID, quantity: quantity, store: preferredStore) {
                    onAdded()
                } else {
                    showingSaveError = true
                }
            }
            .buttonStyle(PassportPrimaryButton())
            .disabled(item == nil)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(PassportTheme.canvas.opacity(0.98))
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                PassportKeyboardDoneButton()
            }
        }
        .onAppear {
            guard !didLoadDefaults else { return }
            didLoadDefaults = true
            preferredStore = store.shopping.first {
                $0.itemID == itemID && !$0.isPurchased
            }?.preferredStore ?? item?.preferredStore ?? ""
        }
        .alert("Shopping item not saved", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(store.lastSaveError ?? "Please try again.")
        }
    }

    private var actionTitle: String {
        if ShoppingItemSelection.activeQuantity(for: itemID, entries: store.shopping) != nil {
            return quantity == 1 ? "Add 1 more" : "Add \(quantity) more"
        }
        return quantity == 1 ? "Add to list" : "Add \(quantity) to list"
    }
}

private struct StoreModeView: View {
    @EnvironmentObject private var store: PassportStore
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var showingSaveError = false
    @State private var showingCopiedConfirmation = false

    private var entries: [ShoppingEntry] { store.shopping.filter { !$0.isPurchased } }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    VStack(spacing: 12) {
                        Text("All picked up")
                            .font(.title.weight(.bold))
                        Text("Record replacements when you install them.")
                            .foregroundStyle(PassportTheme.muted)
                        Button("Done") { dismiss() }
                            .buttonStyle(PassportPrimaryButton())
                    }
                    .padding(24)
                } else if let item = store.item(id: entries[min(index, entries.count - 1)].itemID) {
                    let entry = entries[min(index, entries.count - 1)]
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            SectionEyebrow(title: "\(min(index, entries.count - 1) + 1) of \(entries.count)")
                            ItemArtwork(item: item, photo: store.photo(for: item), size: 160)
                                .frame(maxWidth: .infinity)
                            Text(item.name)
                                .font(.system(size: 31, weight: .bold, design: .rounded))
                                .foregroundStyle(PassportTheme.ink)
                            PassportCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(item.brand).font(.title3)
                                    Text(item.model).font(.title2.weight(.bold)).textSelection(.enabled)
                                    if !item.size.isEmpty { Text(item.size).font(.title3) }
                                    Text("Quantity: \(entry.quantity)")
                                        .font(.headline)
                                    Text("Stock at home: \(item.stockOnHand)")
                                        .font(.subheadline)
                                    if !entry.preferredStore.isEmpty { Text(entry.preferredStore) }
                                    if let price = item.typicalPrice {
                                        Text("Typical price: \(NSDecimalNumber(decimal: price).stringValue)")
                                    }
                                }
                            }
                            if !item.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button("Copy model") {
                                    UIPasteboard.general.string = item.model
                                    showingCopiedConfirmation = true
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                            }
                            if let url = productURL(item.productURL) {
                                Link("Open product link", destination: url)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            Button("Mark bought") {
                                if store.markPurchased(entryID: entry.id) {
                                    index = min(index, max(0, entries.count - 1))
                                } else {
                                    showingSaveError = true
                                }
                            }
                            .buttonStyle(PassportPrimaryButton())
                            Button("Next item") { index = (index + 1) % entries.count }
                                .frame(maxWidth: .infinity)
                        }
                        .padding(24)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PassportTheme.canvas)
            .navigationTitle("Store mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            } }
            .alert("Purchase not saved", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(store.lastSaveError ?? "Please try again.")
            }
            .alert("Model copied", isPresented: $showingCopiedConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The model number is ready to paste.")
            }
        }
        .tint(PassportTheme.teal)
    }

    private func productURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        return URL(string: "https://\(trimmed)")
    }
}
