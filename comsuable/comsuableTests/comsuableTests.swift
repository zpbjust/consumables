import Foundation
import Testing
import UIKit
import UserNotifications
import Vision
@testable import comsuable

struct comsuableTests {
    @Test
    func homeDashboardBuildsSeparateHomeAndRoomSummaries() {
        let primary = Home(name: "My home", rooms: ["Kitchen", "Garage", "Guest room"])
        let cabin = Home(name: "Lake house", rooms: ["Kitchen"])
        let dueItem = ConsumableItem(
            name: "Air filter", category: .hvac, brand: "", model: "", size: "",
            homeID: primary.id, room: "Garage", location: "", notes: "",
            lastReplaced: Date(), intervalDays: 90, remindersEnabled: false
        )
        let currentItem = ConsumableItem(
            name: "Water filter", category: .water, brand: "", model: "", size: "",
            homeID: primary.id, room: "Kitchen", location: "", notes: "",
            lastReplaced: nil, intervalDays: nil, remindersEnabled: false
        )
        let cabinItem = ConsumableItem(
            name: "Smoke alarm", category: .batteries, brand: "", model: "", size: "",
            homeID: cabin.id, room: "Kitchen", location: "", notes: "",
            lastReplaced: nil, intervalDays: nil, remindersEnabled: false
        )
        let legacyRoomItem = ConsumableItem(
            name: "Dehumidifier filter", category: .appliances, brand: "", model: "", size: "",
            homeID: primary.id, room: "Basement", location: "", notes: "",
            lastReplaced: nil, intervalDays: nil, remindersEnabled: false
        )

        let homes = HomeDashboardPresentation.homeSummaries(
            homes: [primary, cabin],
            items: [dueItem, currentItem, cabinItem, legacyRoomItem],
            attentionIDs: Set([dueItem.id])
        )
        #expect(homes.map(\.name) == ["My home", "Lake house"])
        #expect(homes[0].roomCount == 3)
        #expect(homes[0].itemCount == 3)
        #expect(homes[0].attentionCount == 1)
        #expect(homes[1].itemCount == 1)

        let rooms = HomeDashboardPresentation.roomSummaries(
            home: primary,
            items: [dueItem, currentItem, cabinItem, legacyRoomItem],
            attentionIDs: Set([dueItem.id])
        )
        #expect(rooms.map(\.name) == ["Garage", "Kitchen", "Basement", "Guest room"])
        #expect(rooms.map(\.itemCount) == [1, 1, 1, 0])
        #expect(rooms.map(\.attentionCount) == [1, 0, 0, 0])
    }

    @Test
    func pinnedItemsTitleHidesBeforeTheLargeTitleCanOverlapIt() {
        #expect(!PassportPinnedTitleVisibility.next(current: false, titleBottom: 0))
        #expect(PassportPinnedTitleVisibility.next(current: false, titleBottom: -8))
        #expect(PassportPinnedTitleVisibility.next(current: true, titleBottom: -4))
        #expect(!PassportPinnedTitleVisibility.next(current: true, titleBottom: 0))
        #expect(PassportPinnedTitleVisibility.next(
            current: true,
            titleBottom: .greatestFiniteMagnitude
        ))
    }

    @Test
    func replacementHistoryCalculatesObservedCadence() {
        let homeID = UUID()
        let calendar = Calendar(identifier: .gregorian)
        let newest = Date(timeIntervalSince1970: 1_800_000_000)
        let middle = calendar.date(byAdding: .day, value: -90, to: newest)!
        let oldest = calendar.date(byAdding: .day, value: -190, to: newest)!
        let item = ConsumableItem(
            name: "Air filter", category: .hvac, brand: "", model: "AF-1", size: "",
            homeID: homeID, room: "Hallway", location: "", notes: "",
            lastReplaced: newest, intervalDays: 90, remindersEnabled: false,
            history: [
                ReplacementRecord(date: newest, quantity: 1, price: nil, store: "", note: ""),
                ReplacementRecord(date: middle, quantity: 1, price: nil, store: "", note: ""),
                ReplacementRecord(date: oldest, quantity: 1, price: nil, store: "", note: "")
            ]
        )

        #expect(item.averageReplacementDays == 95)
    }

    @MainActor
    @Test func scheduleSeparatesOverdueAndUpcomingItems() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PassportStore(directory: directory)
        let homeID = try #require(store.homes.first?.id)
        let calendar = Calendar.current
        let now = Date()
        let overdue = ConsumableItem(
            name: "Overdue filter", category: .hvac, brand: "", model: "O-1", size: "",
            homeID: homeID, room: "Hallway", location: "", notes: "",
            lastReplaced: calendar.date(byAdding: .day, value: -40, to: now),
            intervalDays: 30, remindersEnabled: false
        )
        let upcoming = ConsumableItem(
            name: "Upcoming filter", category: .water, brand: "", model: "U-1", size: "",
            homeID: homeID, room: "Kitchen", location: "", notes: "",
            lastReplaced: calendar.date(byAdding: .day, value: -20, to: now),
            intervalDays: 30, remindersEnabled: false
        )
        let later = ConsumableItem(
            name: "Later filter", category: .appliances, brand: "", model: "L-1", size: "",
            homeID: homeID, room: "Garage", location: "", notes: "",
            lastReplaced: now, intervalDays: 90, remindersEnabled: false
        )
        let dueToday = ConsumableItem(
            name: "Due today", category: .batteries, brand: "", model: "D-1", size: "",
            homeID: homeID, room: "Bedroom", location: "", notes: "",
            lastReplaced: calendar.date(byAdding: .day, value: -30, to: now),
            intervalDays: 30, remindersEnabled: false
        )
        #expect(store.saveItem(overdue))
        #expect(store.saveItem(upcoming))
        #expect(store.saveItem(later))
        #expect(store.saveItem(dueToday))

        #expect(store.overdueItems(now: now).map(\.id) == [overdue.id])
        #expect(Set(store.upcomingItems(withinDays: 30, now: now).map(\.id)) == Set([dueToday.id, upcoming.id]))
        #expect(store.upcomingItems(withinDays: 14, now: now).map(\.id) == [dueToday.id])
    }

    @Test
    func scheduleCalendarBuildsAStableSixWeekMonthAndFindsDueItemsByDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        calendar.firstWeekday = 1
        let month = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 15)))
        let cells = ScheduleCalendar.monthDates(containing: month, calendar: calendar)

        #expect(cells.count == 42)
        #expect(cells.prefix(2).allSatisfy { $0 == nil })
        #expect(calendar.component(.day, from: try #require(cells[2])) == 1)
        #expect(calendar.component(.day, from: try #require(cells[31])) == 30)

        let homeID = UUID()
        let dueDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 12)))
        let lastReplaced = try #require(calendar.date(byAdding: .day, value: -30, to: dueDate))
        let item = ConsumableItem(
            name: "Air filter", category: .hvac, brand: "", model: "", size: "",
            homeID: homeID, room: "Hallway", location: "", notes: "",
            lastReplaced: lastReplaced, intervalDays: 30, remindersEnabled: false
        )

        #expect(ScheduleCalendar.items([item], dueOn: dueDate, calendar: calendar).map(\.id) == [item.id])
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: dueDate))
        #expect(ScheduleCalendar.items([item], dueOn: nextDay, calendar: calendar).isEmpty)

        let index = ScheduleCalendar.itemIndex(for: [item], calendar: calendar)
        #expect(ScheduleCalendar.isSelectable(dueDate, in: index, calendar: calendar))
        #expect(!ScheduleCalendar.isSelectable(nextDay, in: index, calendar: calendar))
    }

    @Test
    func scheduleStatusFiltersHideWhileADueDateIsSelected() {
        #expect(ScheduleFilterPresentation.showsStatusFilters(selectedDate: nil))
        #expect(!ScheduleFilterPresentation.showsStatusFilters(selectedDate: Date()))
    }

    @Test
    func scheduleTimelineFiltersItemsIntoExclusiveBuckets() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 12)))
        let homeID = UUID()

        func item(named name: String, dueIn days: Int) throws -> ConsumableItem {
            let dueDate = try #require(calendar.date(byAdding: .day, value: days, to: now))
            let lastReplaced = try #require(calendar.date(byAdding: .day, value: -30, to: dueDate))
            return ConsumableItem(
                name: name, category: .other, brand: "", model: "", size: "",
                homeID: homeID, room: "Garage", location: "", notes: "",
                lastReplaced: lastReplaced, intervalDays: 30, remindersEnabled: false
            )
        }

        let overdue = try item(named: "Overdue", dueIn: -1)
        let today = try item(named: "Today", dueIn: 0)
        let comingUp = try item(named: "Coming up", dueIn: 30)
        let later = try item(named: "Later", dueIn: 31)
        let timeline = ScheduleTimeline(
            items: [later, comingUp, overdue, today],
            now: now,
            calendar: calendar
        )

        #expect(timeline.items(for: .overdue).map(\.id) == [overdue.id])
        #expect(timeline.items(for: .comingUp).map(\.id) == [today.id, comingUp.id])
        #expect(timeline.items(for: .later).map(\.id) == [later.id])
        #expect(Set(timeline.items(for: .all).map(\.id)).count == 4)
    }

    @MainActor
    @Test func buyingAndInstallingUpdatesStockOnHand() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PassportStore(directory: directory)
        let homeID = try #require(store.homes.first?.id)
        let item = ConsumableItem(
            name: "Water filter", category: .water, brand: "", model: "W-1", size: "",
            homeID: homeID, room: "Kitchen", location: "", notes: "",
            lastReplaced: nil, intervalDays: 180, remindersEnabled: false,
            stockOnHand: 1
        )
        #expect(store.saveItem(item))
        store.addToShopping(itemID: item.id, quantity: 2)
        let entryID = try #require(store.shopping.first?.id)
        store.markPurchased(entryID: entryID)
        #expect(store.item(id: item.id)?.stockOnHand == 3)
        store.markPurchased(entryID: entryID)
        #expect(store.item(id: item.id)?.stockOnHand == 3)

        store.recordReplacement(itemID: item.id, record: ReplacementRecord(
            date: Date(), quantity: 1, price: Decimal(42), store: "Neighborhood Hardware", note: ""
        ))
        #expect(store.item(id: item.id)?.stockOnHand == 2)
        #expect(store.item(id: item.id)?.preferredStore == "Neighborhood Hardware")
        #expect(store.item(id: item.id)?.typicalPrice == Decimal(42))

        store.recordReplacement(itemID: item.id, record: ReplacementRecord(
            date: Date(), quantity: 99, price: nil, store: "", note: ""
        ))
        #expect(store.item(id: item.id)?.stockOnHand == 0)

        let reloaded = PassportStore(directory: directory)
        #expect(reloaded.item(id: item.id)?.stockOnHand == 0)
        #expect(reloaded.item(id: item.id)?.preferredStore == "Neighborhood Hardware")
        #expect(reloaded.item(id: item.id)?.typicalPrice == Decimal(42))
    }

    @MainActor
    @Test
    func shoppingItemSelectionSearchesUsefulDetailsAndShowsExistingQuantity() throws {
        let homeID = UUID()
        let airFilter = ConsumableItem(
            name: "Upstairs Air Filter", category: .hvac, brand: "Filtrete", model: "MPR-1000",
            size: "16 x 25 x 1", homeID: homeID, room: "Living room",
            location: "Upstairs ceiling return vent", notes: "", lastReplaced: nil,
            intervalDays: 90, remindersEnabled: false
        )
        let waterFilter = ConsumableItem(
            name: "Fridge Water Filter", category: .water, brand: "EveryDrop", model: "EDR4RXD1",
            size: "", homeID: homeID, room: "Kitchen", location: "Refrigerator", notes: "",
            lastReplaced: nil, intervalDays: 180, remindersEnabled: false
        )
        let entry = ShoppingEntry(itemID: airFilter.id, quantity: 2)

        #expect(ShoppingItemSelection.filteredItems([waterFilter, airFilter], query: "mpr") == [airFilter])
        #expect(ShoppingItemSelection.filteredItems([waterFilter, airFilter], query: "").map(\.name) == [
            "Fridge Water Filter", "Upstairs Air Filter"
        ])
        #expect(ShoppingItemSelection.activeQuantity(for: airFilter.id, entries: [entry]) == 2)
        #expect(ShoppingItemSelection.activeQuantity(for: waterFilter.id, entries: [entry]) == nil)
    }

    @MainActor
    @Test
    func addingTheSameItemAgainIncreasesOneActiveShoppingEntry() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PassportStore(directory: directory)
        let homeID = try #require(store.homes.first?.id)
        let item = ConsumableItem(
            name: "Air filter", category: .hvac, brand: "", model: "AF-1", size: "",
            homeID: homeID, room: "Hallway", location: "", notes: "",
            lastReplaced: nil, intervalDays: 90, remindersEnabled: false
        )
        #expect(store.saveItem(item))

        #expect(store.addToShopping(itemID: item.id))
        #expect(store.addToShopping(itemID: item.id))

        #expect(store.shopping.filter { !$0.isPurchased }.count == 1)
        #expect(store.shopping.first?.quantity == 2)
    }

    @MainActor
    @Test func replacementHistoryExportsAsEscapedCSV() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PassportStore(directory: directory)
        let homeID = try #require(store.homes.first?.id)
        let item = ConsumableItem(
            name: "Filter, upstairs", category: .hvac, brand: "", model: "F-1", size: "16 x 25 x 1",
            homeID: homeID, room: "Hallway", location: "", notes: "",
            lastReplaced: nil, intervalDays: 90, remindersEnabled: false
        )
        #expect(store.saveItem(item))
        store.recordReplacement(itemID: item.id, record: ReplacementRecord(
            date: Date(timeIntervalSince1970: 1_700_000_000), quantity: 1, price: Decimal(string: "18.99"),
            store: "Home, Supply", note: "Used \"premium\" filter"
        ))

        let url = try store.exportReplacementHistory()
        defer { try? FileManager.default.removeItem(at: url) }
        let csv = try String(contentsOf: url, encoding: .utf8)

        #expect(csv.contains("\"Filter, upstairs\""))
        #expect(csv.contains("\"Home, Supply\""))
        #expect(csv.contains("\"Used \"\"premium\"\" filter\""))
    }

    @Test func oneHomeDoesNotShowAHomePicker() {
        #expect(!LocationPresentation.showsHomePicker(homeCount: 1))
        #expect(LocationPresentation.showsHomePicker(homeCount: 2))
    }

    @MainActor
    @Test func backfilledReplacementKeepsLatestDateAndSortedHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PassportStore(directory: directory)
        let homeID = try #require(store.homes.first?.id)
        let today = Calendar.current.startOfDay(for: Date())
        let older = Calendar.current.date(byAdding: .day, value: -60, to: today)!
        let item = ConsumableItem(
            name: "Air filter", category: .hvac, brand: "", model: "AF-1", size: "",
            homeID: homeID, room: "Hallway", location: "", notes: "",
            lastReplaced: today, intervalDays: 90, remindersEnabled: false
        )
        #expect(store.saveItem(item))
        #expect(store.recordReplacement(itemID: item.id, record: ReplacementRecord(
            date: older, quantity: 1, price: nil, store: "", note: "Backfilled"
        )))

        let saved = try #require(store.item(id: item.id))
        #expect(saved.lastReplaced == today)
        #expect(saved.history.map(\.date) == [older])
    }

    @MainActor
    @Test func failedPersistenceRollsBackInMemoryMutation() throws {
        let fileInsteadOfDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("blocked".utf8).write(to: fileInsteadOfDirectory)
        defer { try? FileManager.default.removeItem(at: fileInsteadOfDirectory) }
        let store = PassportStore(directory: fileInsteadOfDirectory)
        let originalHomes = store.homes

        #expect(!store.addHome(name: "Cabin"))
        #expect(store.homes == originalHomes)
        #expect(store.lastSaveError != nil)
    }

    @Test @MainActor func newlyAddedBuyingFieldsRemainBackwardCompatible() throws {
        let home = Home(name: "My home")
        let legacyItem: [String: Any] = [
            "id": UUID().uuidString,
            "name": "Legacy filter",
            "category": "HVAC filters",
            "brand": "Acme",
            "model": "OLD-1",
            "size": "16 x 25 x 1",
            "homeID": home.id.uuidString,
            "room": "Garage",
            "location": "Return vent",
            "notes": "",
            "remindersEnabled": false,
            "history": [],
            "createdAt": 0.0
        ]
        let object: [String: Any] = [
            "homes": [[
                "id": home.id.uuidString,
                "name": home.name,
                "rooms": home.rooms
            ]],
            "items": [legacyItem],
            "shopping": [],
            "reminderLeadDays": 3
        ]
        let bytes = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(PassportData.self, from: bytes)

        #expect(decoded.items.first?.stockOnHand == 0)
        #expect(decoded.items.first?.preferredStore.isEmpty == true)
        #expect(decoded.items.first?.productURL.isEmpty == true)
        #expect(decoded.items.first?.typicalPrice == nil)
    }

    @Test @MainActor
    func blankTapDismissesKeyboardWithoutStealingInputOrControlTaps() {
        let background = UIView()
        #expect(KeyboardDismissPolicy.shouldDismiss(for: background))

        let textField = UITextField()
        background.addSubview(textField)
        #expect(!KeyboardDismissPolicy.shouldDismiss(for: textField))

        let textView = UITextView()
        background.addSubview(textView)
        #expect(!KeyboardDismissPolicy.shouldDismiss(for: textView))

        let control = UIControl()
        let controlLabel = UILabel()
        control.addSubview(controlLabel)
        background.addSubview(control)
        #expect(!KeyboardDismissPolicy.shouldDismiss(for: controlLabel))
    }

    @Test func parsesEnglishHVACLabelIntoEditableDetails() {
        let result = LabelScanParser.parse(lines: [
            "Filtrete", "FURNACE FILTER", "MODEL: MPR-1000", "SIZE: 16 x 25 x 1 in"
        ])

        #expect(result.suggestedName == "Furnace Filter")
        #expect(result.brand == "Filtrete")
        #expect(result.model == "MPR-1000")
        #expect(result.size == "16 x 25 x 1 in")
        #expect(result.category == .hvac)
    }

    @Test func parsesChineseWaterFilterLabelIntoEditableDetails() {
        let result = LabelScanParser.parse(lines: [
            "品牌：清泉", "产品名称：净水器滤芯", "型号：QY-RO-05", "规格：10英寸"
        ])

        #expect(result.suggestedName == "净水器滤芯")
        #expect(result.brand == "清泉")
        #expect(result.model == "QY-RO-05")
        #expect(result.size == "10英寸")
        #expect(result.category == .water)
    }

    @Test func fallsBackToUnlabeledModelAndDimensions() {
        let result = LabelScanParser.parse(lines: [
            "AquaPure", "REFRIGERATOR WATER FILTER", "AP-4396508", "10.2 x 2.4 in"
        ])

        #expect(result.brand == "AquaPure")
        #expect(result.model == "AP-4396508")
        #expect(result.size == "10.2 x 2.4 in")
        #expect(result.category == .water)
    }

    @Test func parsesWarmLightBulbLabelAndKeepsTheFullSpecification() {
        let result = LabelScanParser.parse(lines: [
            "LumaHome", "LED LIGHT BULB", "MODEL: LH-A19-9W", "SPEC: A19 / 9W / 800 lm"
        ])

        #expect(result.brand == "LumaHome")
        #expect(result.model == "LH-A19-9W")
        #expect(result.size == "A19 / 9W / 800 lm")
        #expect(result.category == .lighting)
    }

    @Test func parsesUnlabeledVacuumFilterValues() {
        let result = LabelScanParser.parse(lines: [
            "CleanNest", "VACUUM HEPA FILTER", "CN-HF220", "9.5 x 8.2 x 1.1 in"
        ])

        #expect(result.brand == "CleanNest")
        #expect(result.model == "CN-HF220")
        #expect(result.size == "9.5 x 8.2 x 1.1 in")
        #expect(result.category == .appliances)
    }

    @Test func keepsHyphenatedModelWhenTheLabelHasNoColon() {
        let result = LabelScanParser.parse(lines: ["MODEL LH-A19-9W", "Part No. AP-4396508"])

        #expect(result.model == "LH-A19-9W")
    }

    @Test func labelRecognitionAutomaticallyDetectsChineseAndEnglish() {
        let request = LabelTextRecognition.makeRequest()

        #expect(request.revision == VNRecognizeTextRequestRevision3)
        #expect(request.recognitionLevel == .accurate)
        #expect(request.automaticallyDetectsLanguage)
        #expect(request.usesLanguageCorrection)
    }

    @Test func freePlanLimitsItemsAndHomesWithoutBlockingEdits() {
        #expect(PremiumAccessPolicy.canCreateItem(
            existingItemCount: 4, isPro: false, purchasesConfigured: true
        ))
        #expect(!PremiumAccessPolicy.canCreateItem(
            existingItemCount: 5, isPro: false, purchasesConfigured: true
        ))
        #expect(PremiumAccessPolicy.canCreateItem(
            existingItemCount: 5, isPro: true, purchasesConfigured: true
        ))
        #expect(PremiumAccessPolicy.canCreateHome(
            existingHomeCount: 0, isPro: false, purchasesConfigured: true
        ))
        #expect(!PremiumAccessPolicy.canCreateHome(
            existingHomeCount: 1, isPro: false, purchasesConfigured: true
        ))
        #expect(PremiumAccessPolicy.canCreateHome(
            existingHomeCount: 1, isPro: true, purchasesConfigured: true
        ))
    }

    @Test func unconfiguredPurchasesLeaveEveryFeatureAvailableForTesting() {
        #expect(PremiumAccessPolicy.canCreateItem(
            existingItemCount: 100, isPro: false, purchasesConfigured: false
        ))
        #expect(PremiumAccessPolicy.canCreateHome(
            existingHomeCount: 100, isPro: false, purchasesConfigured: false
        ))
    }

    @Test func dueDateAndSearchUseSavedDetails() {
        let homeID = UUID()
        let item = ConsumableItem(
            name: "Furnace filter", category: .hvac, brand: "Nordic Pure",
            model: "NP-20251", size: "20 x 25 x 1 in", homeID: homeID,
            room: "Garage", location: "Main return", notes: "",
            lastReplaced: Date(timeIntervalSince1970: 1_700_000_000),
            intervalDays: 90, remindersEnabled: false
        )
        #expect(item.matches("NP-20251"))
        #expect(item.matches("garage"))
        #expect(!item.matches("refrigerator"))
        #expect(item.nextDueDate == Calendar.current.date(byAdding: .day, value: 90, to: item.lastReplaced!))
    }

    @MainActor
    @Test func savesAndReloadsItemsShoppingAndReplacement() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PassportStore(directory: directory)
        let homeID = try #require(store.homes.first?.id)
        let item = ConsumableItem(
            name: "Water filter", category: .water, brand: "Acme", model: "W-1",
            size: "", homeID: homeID, room: "Kitchen", location: "Fridge", notes: "",
            lastReplaced: Date(), intervalDays: 180, remindersEnabled: false,
            stockOnHand: 2, preferredStore: "Target", productURL: "https://example.com/filter",
            typicalPrice: Decimal(string: "12.50")
        )
        #expect(store.saveItem(item))
        store.addToShopping(itemID: item.id, quantity: 2)
        let entryID = try #require(store.shopping.first?.id)
        store.markPurchased(entryID: entryID)
        store.recordReplacement(itemID: item.id, record: ReplacementRecord(
            date: Date(), quantity: 2, price: Decimal(24), store: "Local store", note: ""
        ))

        let reloaded = PassportStore(directory: directory)
        #expect(reloaded.items.count == 1)
        #expect(reloaded.items.first?.history.count == 1)
        #expect(reloaded.shopping.isEmpty)
        #expect(reloaded.items.first?.model == "W-1")
        #expect(reloaded.items.first?.stockOnHand == 2)
        #expect(reloaded.items.first?.preferredStore == "Local store")
        #expect(reloaded.items.first?.productURL == "https://example.com/filter")
        #expect(reloaded.items.first?.typicalPrice == Decimal(12))
    }

    @MainActor
    @Test func backupRoundTripAndHomeDeletionSafety() throws {
        let firstDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let secondDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: firstDirectory)
            try? FileManager.default.removeItem(at: secondDirectory)
        }
        let first = PassportStore(directory: firstDirectory)
        let homeID = try #require(first.homes.first?.id)
        let item = ConsumableItem(
            name: "Lamp bulb", category: .lighting, brand: "", model: "A19",
            size: "", homeID: homeID, room: "Bedroom", location: "Bedside", notes: "",
            lastReplaced: nil, intervalDays: nil, remindersEnabled: false
        )
        #expect(first.saveItem(item))
        first.addHome(name: "Cabin")
        #expect(!first.deleteHome(id: homeID))

        let backup = try first.exportData()
        defer { try? FileManager.default.removeItem(at: backup) }
        let second = PassportStore(directory: secondDirectory)
        try second.importData(from: backup)
        #expect(second.items.map(\.model) == ["A19"])
        #expect(second.homes.count == 2)
        second.deleteItem(id: item.id)
        #expect(second.deleteHome(id: homeID))
    }

    @MainActor
    @Test func photosAreDownsampledAndRenamedHomesPersist() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PassportStore(directory: directory)
        let homeID = try #require(store.homes.first?.id)
        let item = ConsumableItem(
            name: "Air filter", category: .hvac, brand: "", model: "20X25",
            size: "20 x 25 x 1", homeID: homeID, room: "Garage", location: "",
            notes: "", lastReplaced: nil, intervalDays: nil, remindersEnabled: false
        )
        let largePhoto = UIGraphicsImageRenderer(size: CGSize(width: 2_400, height: 1_800)).image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2_400, height: 1_800))
        }

        #expect(store.saveItem(item, image: largePhoto))
        let savedItem = try #require(store.item(id: item.id))
        let savedPhoto = try #require(store.photo(for: savedItem))
        #expect(max(savedPhoto.size.width, savedPhoto.size.height) <= 1_600)

        store.renameHome(id: homeID, name: "Lake house")
        let reloaded = PassportStore(directory: directory)
        #expect(reloaded.home(id: homeID)?.name == "Lake house")
    }

    @MainActor
    @Test func roomsCanBeRenamedAndOnlyEmptyRoomsCanBeDeleted() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PassportStore(directory: directory)
        let homeID = try #require(store.homes.first?.id)

        store.addRoom("Utility room", homeID: homeID)
        #expect(store.renameRoom("Utility room", to: "Mudroom", homeID: homeID))
        #expect(store.home(id: homeID)?.rooms.contains("Mudroom") == true)

        let item = ConsumableItem(
            name: "Dehumidifier filter", category: .appliances, brand: "", model: "DF-1",
            size: "", homeID: homeID, room: "Mudroom", location: "", notes: "",
            lastReplaced: nil, intervalDays: nil, remindersEnabled: false
        )
        #expect(store.saveItem(item))
        #expect(!store.deleteRoom("Mudroom", homeID: homeID))
        store.deleteItem(id: item.id)
        #expect(store.deleteRoom("Mudroom", homeID: homeID))
    }

    @Test func reminderUsesNineAMAndRejectsPastTimeOnSameDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let homeID = UUID()
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 25, hour: 10
        )))
        let item = ConsumableItem(
            name: "Filter", category: .hvac, brand: "", model: "F-1", size: "",
            homeID: homeID, room: "Garage", location: "", notes: "",
            lastReplaced: now, intervalDays: 1, remindersEnabled: true
        )

        let tomorrow = try #require(ReminderService.notificationDate(
            for: item, leadDays: 0, now: now, calendar: calendar
        ))
        #expect(calendar.component(.hour, from: tomorrow) == 9)
        #expect(calendar.component(.day, from: tomorrow) == 26)

        #expect(ReminderService.notificationDate(
            for: item, leadDays: 1, now: now, calendar: calendar
        ) == nil)
    }

    @MainActor
    @Test func notificationPermissionStateExplainsEverySystemAuthorizationStatus() {
        #expect(NotificationPermissionState(status: .notDetermined) == .notRequested)
        #expect(NotificationPermissionState(status: .denied) == .denied)
        #expect(NotificationPermissionState(status: .authorized) == .allowed)
        #expect(NotificationPermissionState(status: .provisional) == .allowed)
        #expect(NotificationPermissionState(status: .ephemeral) == .allowed)
    }
}
