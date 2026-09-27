import Foundation

enum ItemCategory: String, CaseIterable, Codable, Identifiable {
    case hvac = "HVAC filters"
    case water = "Water filters"
    case lighting = "Light bulbs"
    case batteries = "Batteries"
    case appliances = "Appliances"
    case other = "Other"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .hvac: "Air & HVAC filters"
        case .water: "Water filters"
        case .lighting: "Light bulbs"
        case .batteries: "Batteries"
        case .appliances: "Appliance parts"
        case .other: "Other"
        }
    }

    var exampleName: String {
        switch self {
        case .hvac: "Air filter"
        case .water: "Refrigerator water filter"
        case .lighting: "Kitchen light bulb"
        case .batteries: "Smoke alarm batteries"
        case .appliances: "Robot vacuum filter"
        case .other: "Replacement item"
        }
    }
    var assetName: String {
        switch self {
        case .hvac: "CategoryFilter"
        case .water: "CategoryWater"
        case .lighting: "CategoryBulb"
        case .batteries: "CategoryBattery"
        case .appliances: "CategoryAppliance"
        case .other: "CategoryOther"
        }
    }
}

struct Home: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var rooms: [String] = ["Kitchen", "Living room", "Bedroom", "Bathroom", "Garage"]
}

struct ReplacementRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var quantity: Int
    var price: Decimal?
    var store: String
    var note: String
}

struct ConsumableItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var category: ItemCategory
    var brand: String
    var model: String
    var size: String
    var homeID: UUID
    var room: String
    var location: String
    var notes: String
    var imageFilename: String?
    var lastReplaced: Date?
    var intervalDays: Int?
    var remindersEnabled: Bool
    var history: [ReplacementRecord] = []
    var createdAt = Date()
    var stockOnHand: Int = 0
    var preferredStore: String = ""
    var productURL: String = ""
    var typicalPrice: Decimal?

    init(
        id: UUID = UUID(),
        name: String,
        category: ItemCategory,
        brand: String,
        model: String,
        size: String,
        homeID: UUID,
        room: String,
        location: String,
        notes: String,
        imageFilename: String? = nil,
        lastReplaced: Date?,
        intervalDays: Int?,
        remindersEnabled: Bool,
        history: [ReplacementRecord] = [],
        createdAt: Date = Date(),
        stockOnHand: Int = 0,
        preferredStore: String = "",
        productURL: String = "",
        typicalPrice: Decimal? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.brand = brand
        self.model = model
        self.size = size
        self.homeID = homeID
        self.room = room
        self.location = location
        self.notes = notes
        self.imageFilename = imageFilename
        self.lastReplaced = lastReplaced
        self.intervalDays = intervalDays
        self.remindersEnabled = remindersEnabled
        self.history = history
        self.createdAt = createdAt
        self.stockOnHand = max(0, stockOnHand)
        self.preferredStore = preferredStore
        self.productURL = productURL
        self.typicalPrice = typicalPrice
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, category, brand, model, size, homeID, room, location, notes
        case imageFilename, lastReplaced, intervalDays, remindersEnabled, history, createdAt
        case stockOnHand, preferredStore, productURL, typicalPrice
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(ItemCategory.self, forKey: .category)
        brand = try container.decode(String.self, forKey: .brand)
        model = try container.decode(String.self, forKey: .model)
        size = try container.decode(String.self, forKey: .size)
        homeID = try container.decode(UUID.self, forKey: .homeID)
        room = try container.decode(String.self, forKey: .room)
        location = try container.decode(String.self, forKey: .location)
        notes = try container.decode(String.self, forKey: .notes)
        imageFilename = try container.decodeIfPresent(String.self, forKey: .imageFilename)
        lastReplaced = try container.decodeIfPresent(Date.self, forKey: .lastReplaced)
        intervalDays = try container.decodeIfPresent(Int.self, forKey: .intervalDays)
        remindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? false
        history = try container.decodeIfPresent([ReplacementRecord].self, forKey: .history) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        stockOnHand = max(0, try container.decodeIfPresent(Int.self, forKey: .stockOnHand) ?? 0)
        preferredStore = try container.decodeIfPresent(String.self, forKey: .preferredStore) ?? ""
        productURL = try container.decodeIfPresent(String.self, forKey: .productURL) ?? ""
        typicalPrice = try container.decodeIfPresent(Decimal.self, forKey: .typicalPrice)
    }

    var nextDueDate: Date? {
        guard let lastReplaced, let intervalDays else { return nil }
        return Calendar.current.date(byAdding: .day, value: intervalDays, to: lastReplaced)
    }

    func isOverdue(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let nextDueDate else { return false }
        return calendar.startOfDay(for: nextDueDate) < calendar.startOfDay(for: date)
    }

    var averageReplacementDays: Int? {
        let dates = history.map(\.date).sorted(by: >)
        guard dates.count > 1 else { return nil }
        let intervals = zip(dates, dates.dropFirst()).compactMap { newer, older in
            Calendar.current.dateComponents([.day], from: older, to: newer).day
        }.filter { $0 > 0 }
        guard !intervals.isEmpty else { return nil }
        return Int((Double(intervals.reduce(0, +)) / Double(intervals.count)).rounded())
    }

    func matches(_ query: String) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return true }
        return [name, brand, model, size, room, location, category.rawValue, category.displayName, preferredStore]
            .contains { $0.localizedCaseInsensitiveContains(term) }
    }
}

enum LocationPresentation {
    static func showsHomePicker(homeCount: Int) -> Bool { homeCount > 1 }
}

enum HomeDashboardPresentation {
    struct HomeSummary: Identifiable, Equatable {
        let id: UUID
        let name: String
        let roomCount: Int
        let itemCount: Int
        let attentionCount: Int
    }

    struct RoomSummary: Identifiable, Equatable {
        var id: String { name }
        let name: String
        let itemCount: Int
        let attentionCount: Int
    }

    static func homeSummaries(
        homes: [Home],
        items: [ConsumableItem],
        attentionIDs: Set<UUID>
    ) -> [HomeSummary] {
        let itemsByHome = Dictionary(grouping: items, by: \.homeID)
        return homes.map { home in
            let homeItems = itemsByHome[home.id] ?? []
            return HomeSummary(
                id: home.id,
                name: home.name,
                roomCount: home.rooms.count,
                itemCount: homeItems.count,
                attentionCount: homeItems.filter { attentionIDs.contains($0.id) }.count
            )
        }
    }

    static func roomSummaries(
        home: Home,
        items: [ConsumableItem],
        attentionIDs: Set<UUID>
    ) -> [RoomSummary] {
        let homeItems = items.filter { $0.homeID == home.id }
        let itemsByRoom = Dictionary(grouping: homeItems, by: \.room)
        var roomNames = home.rooms
        for room in homeItems.map(\.room) where
            !room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !roomNames.contains(where: { $0.localizedCaseInsensitiveCompare(room) == .orderedSame }) {
            roomNames.append(room)
        }

        return roomNames.enumerated().map { index, room in
            let roomItems = itemsByRoom[room] ?? []
            return (
                index: index,
                summary: RoomSummary(
                    name: room,
                    itemCount: roomItems.count,
                    attentionCount: roomItems.filter { attentionIDs.contains($0.id) }.count
                )
            )
        }
        .sorted {
            if $0.summary.attentionCount != $1.summary.attentionCount {
                return $0.summary.attentionCount > $1.summary.attentionCount
            }
            if ($0.summary.itemCount == 0) != ($1.summary.itemCount == 0) {
                return $0.summary.itemCount > 0
            }
            return $0.index < $1.index
        }
        .map(\.summary)
    }
}

struct ShoppingEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var itemID: UUID
    var quantity: Int = 1
    var preferredStore: String = ""
    var isPurchased = false
}

struct PassportData: Codable, Equatable {
    var homes: [Home] = [Home(name: "My home")]
    var items: [ConsumableItem] = []
    var shopping: [ShoppingEntry] = []
    var reminderLeadDays = 3
}
