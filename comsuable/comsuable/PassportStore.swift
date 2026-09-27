import Combine
import Foundation
import UIKit

@MainActor
final class PassportStore: ObservableObject {
    @Published private(set) var data: PassportData
    @Published private(set) var lastSaveError: String?

    private let directory: URL
    private let fileURL: URL
    private let imagesURL: URL

    init(directory: URL? = nil) {
        let root = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("HomePassport", isDirectory: true)
#if DEBUG
        if directory == nil, ProcessInfo.processInfo.arguments.contains("--reset-test-data") {
            try? FileManager.default.removeItem(at: root)
        }
#endif
        self.directory = root
        fileURL = root.appendingPathComponent("passport.json")
        imagesURL = root.appendingPathComponent("Images", isDirectory: true)

        if let bytes = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(PassportData.self, from: bytes) {
            data = decoded
        } else {
            data = PassportData()
        }
    }

    var homes: [Home] { data.homes }
    var items: [ConsumableItem] { data.items }
    var shopping: [ShoppingEntry] { data.shopping }
    var reminderLeadDays: Int { data.reminderLeadDays }

    func overdueItems(now: Date = Date()) -> [ConsumableItem] {
        ScheduleTimeline(items: items, now: now).overdue
    }

    func upcomingItems(withinDays days: Int = 30, now: Date = Date()) -> [ConsumableItem] {
        ScheduleTimeline(items: items, comingUpDays: days, now: now).comingUp
    }

    var scheduledItems: [ConsumableItem] {
        items.filter { $0.nextDueDate != nil }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }

    func item(id: UUID) -> ConsumableItem? { items.first { $0.id == id } }
    func home(id: UUID) -> Home? { homes.first { $0.id == id } }

    @discardableResult
    func saveItem(_ item: ConsumableItem, image: UIImage? = nil) -> Bool {
        var updated = item
        let previous = data
        var writtenImageURL: URL?
        var previousImageBytes: Data?
        do {
            if let image {
                try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
                let filename = "\(item.id.uuidString).jpg"
                let imageURL = imagesURL.appendingPathComponent(filename)
                let preparedImage = image.preparingForLocalStorage(maxPixelDimension: 1_600)
                guard let bytes = preparedImage.jpegData(compressionQuality: 0.78) else { return false }
                previousImageBytes = try? Data(contentsOf: imageURL)
                try bytes.write(to: imageURL, options: .atomic)
                writtenImageURL = imageURL
                updated.imageFilename = filename
            }
            if let index = data.items.firstIndex(where: { $0.id == item.id }) {
                data.items[index] = updated
            } else {
                data.items.append(updated)
            }
            guard persist() else {
                data = previous
                restoreImage(at: writtenImageURL, previousBytes: previousImageBytes)
                return false
            }
            ReminderService.schedule(item: updated, leadDays: data.reminderLeadDays)
            return true
        } catch {
            data = previous
            restoreImage(at: writtenImageURL, previousBytes: previousImageBytes)
            lastSaveError = "The photo could not be saved. Try again."
            return false
        }
    }

    @discardableResult
    func deleteItem(id: UUID) -> Bool {
        guard let item = item(id: id) else { return false }
        guard commit({ data in
            data.items.removeAll { $0.id == id }
            data.shopping.removeAll { $0.itemID == id }
        }) else { return false }
        ReminderService.cancel(itemID: id)
        if let filename = item.imageFilename {
            try? FileManager.default.removeItem(at: imagesURL.appendingPathComponent(filename))
        }
        return true
    }

    func photo(for item: ConsumableItem) -> UIImage? {
        guard let filename = item.imageFilename,
              let bytes = try? Data(contentsOf: imagesURL.appendingPathComponent(filename)) else { return nil }
        return UIImage(data: bytes)
    }

    @discardableResult
    func addToShopping(itemID: UUID, quantity: Int = 1, store: String = "") -> Bool {
        guard let item = item(id: itemID) else { return false }
        let preferredStore = store.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? item.preferredStore
            : store
        return commit { data in
            if let index = data.shopping.firstIndex(where: { $0.itemID == itemID && !$0.isPurchased }) {
                data.shopping[index].quantity += max(1, quantity)
                if !preferredStore.isEmpty { data.shopping[index].preferredStore = preferredStore }
            } else {
                data.shopping.append(ShoppingEntry(
                    itemID: itemID,
                    quantity: max(1, quantity),
                    preferredStore: preferredStore
                ))
            }
        }
    }

    @discardableResult
    func markPurchased(entryID: UUID) -> Bool {
        guard let index = data.shopping.firstIndex(where: { $0.id == entryID }),
              let itemIndex = data.items.firstIndex(where: { $0.id == data.shopping[index].itemID }) else { return false }
        guard !data.shopping[index].isPurchased else { return true }
        return commit { data in
            data.shopping[index].isPurchased = true
            data.items[itemIndex].stockOnHand += data.shopping[index].quantity
        }
    }

    @discardableResult
    func removeShopping(entryID: UUID) -> Bool {
        guard data.shopping.contains(where: { $0.id == entryID }) else { return false }
        return commit { $0.shopping.removeAll { $0.id == entryID } }
    }

    @discardableResult
    func recordReplacement(itemID: UUID, record: ReplacementRecord) -> Bool {
        let calendar = Calendar.current
        guard calendar.startOfDay(for: record.date) <= calendar.startOfDay(for: Date()),
              let index = data.items.firstIndex(where: { $0.id == itemID }) else { return false }
        let existingLastReplaced = data.items[index].lastReplaced
        let isLatestRecord = existingLastReplaced.map { record.date >= $0 } ?? true
        guard commit({ data in
            data.items[index].history.append(record)
            data.items[index].history.sort { $0.date > $1.date }
            data.items[index].lastReplaced = [existingLastReplaced, data.items[index].history.first?.date]
                .compactMap { $0 }
                .max()
            data.items[index].stockOnHand = max(0, data.items[index].stockOnHand - max(1, record.quantity))
            if isLatestRecord, !record.store.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                data.items[index].preferredStore = record.store
            }
            if isLatestRecord, let price = record.price, record.quantity > 0 {
                data.items[index].typicalPrice = price / Decimal(record.quantity)
            }
            data.shopping.removeAll { $0.itemID == itemID && $0.isPurchased }
        }) else { return false }
        let item = data.items[index]
        ReminderService.schedule(item: item, leadDays: data.reminderLeadDays)
        return true
    }

    @discardableResult
    func addHome(name: String) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        return commit { $0.homes.append(Home(name: clean)) }
    }

    @discardableResult
    func renameHome(id: UUID, name: String) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let index = data.homes.firstIndex(where: { $0.id == id }) else { return false }
        return commit { $0.homes[index].name = clean }
    }

    func deleteHome(id: UUID) -> Bool {
        guard data.homes.count > 1, !data.items.contains(where: { $0.homeID == id }) else { return false }
        return commit { $0.homes.removeAll { $0.id == id } }
    }

    @discardableResult
    func addRoom(_ room: String, homeID: UUID) -> Bool {
        let clean = room.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let index = data.homes.firstIndex(where: { $0.id == homeID }),
              !data.homes[index].rooms.contains(where: { $0.localizedCaseInsensitiveCompare(clean) == .orderedSame }) else { return false }
        return commit { $0.homes[index].rooms.append(clean) }
    }

    @discardableResult
    func renameRoom(_ room: String, to newName: String, homeID: UUID) -> Bool {
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty,
              let homeIndex = data.homes.firstIndex(where: { $0.id == homeID }),
              let roomIndex = data.homes[homeIndex].rooms.firstIndex(of: room),
              !data.homes[homeIndex].rooms.contains(where: {
                  $0 != room && $0.localizedCaseInsensitiveCompare(clean) == .orderedSame
              }) else { return false }

        let previous = data
        data.homes[homeIndex].rooms[roomIndex] = clean
        for itemIndex in data.items.indices where
            data.items[itemIndex].homeID == homeID && data.items[itemIndex].room == room {
            data.items[itemIndex].room = clean
        }
        guard persist() else {
            data = previous
            return false
        }
        return true
    }

    @discardableResult
    func deleteRoom(_ room: String, homeID: UUID) -> Bool {
        guard let homeIndex = data.homes.firstIndex(where: { $0.id == homeID }),
              data.homes[homeIndex].rooms.count > 1,
              !data.items.contains(where: { $0.homeID == homeID && $0.room == room }) else {
            return false
        }
        let previous = data
        data.homes[homeIndex].rooms.removeAll { $0 == room }
        guard persist() else {
            data = previous
            return false
        }
        return true
    }

    @discardableResult
    func setReminderLeadDays(_ days: Int) -> Bool {
        guard commit({ $0.reminderLeadDays = max(0, min(days, 30)) }) else { return false }
        items.forEach { ReminderService.schedule(item: $0, leadDays: data.reminderLeadDays) }
        return true
    }

    func exportData() throws -> URL {
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Home-Passport-Backup-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))).json")
        var photos: [String: Data] = [:]
        for filename in Set(items.compactMap(\.imageFilename)) {
            photos[filename] = try Data(contentsOf: imagesURL.appendingPathComponent(filename))
        }
        let bytes = try JSONEncoder().encode(PassportBackup(data: data, photos: photos))
        try bytes.write(to: exportURL, options: .atomic)
        return exportURL
    }

    func exportReplacementHistory() throws -> URL {
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Home-Passport-History-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))).csv")
        var rows = ["Item,Category,Home,Room,Date,Quantity,Price,Store,Note"]
        let dateFormatter = ISO8601DateFormatter()
        for item in items {
            let homeName = home(id: item.homeID)?.name ?? ""
            for record in item.history.sorted(by: { $0.date > $1.date }) {
                rows.append([
                    item.name,
                    item.category.displayName,
                    homeName,
                    item.room,
                    dateFormatter.string(from: record.date),
                    String(record.quantity),
                    record.price.map { NSDecimalNumber(decimal: $0).stringValue } ?? "",
                    record.store,
                    record.note
                ].map(csvField).joined(separator: ","))
            }
        }
        try Data(rows.joined(separator: "\n").utf8).write(to: exportURL, options: .atomic)
        return exportURL
    }

    func importData(from url: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let bytes = try Data(contentsOf: url)
        let backup = try JSONDecoder().decode(PassportBackup.self, from: bytes)
        let incoming = backup.data
        guard !incoming.homes.isEmpty else { throw ImportError.noHomes }
        // Reject malformed links before replacing existing user data.
        let homeIDs = Set(incoming.homes.map(\.id))
        guard incoming.items.allSatisfy({ homeIDs.contains($0.homeID) }) else { throw ImportError.invalidHomeLink }
        let itemIDs = Set(incoming.items.map(\.id))
        guard incoming.shopping.allSatisfy({ itemIDs.contains($0.itemID) }) else { throw ImportError.invalidItemLink }
        let referencedPhotos = Set(incoming.items.compactMap(\.imageFilename))
        guard referencedPhotos.isSubset(of: Set(backup.photos.keys)),
              referencedPhotos.allSatisfy({ $0 == URL(fileURLWithPath: $0).lastPathComponent && $0.hasSuffix(".jpg") })
        else { throw ImportError.invalidPhoto }
        let previous = data
        let previousItemIDs = Set(previous.items.map(\.id))
        let previousPhotoNames = Set(previous.items.compactMap(\.imageFilename))
        var previousPhotoBytes: [String: Data] = [:]
        var writtenPhotoNames = Set<String>()

        do {
            try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
            for (filename, imageBytes) in backup.photos where referencedPhotos.contains(filename) {
                let destination = imagesURL.appendingPathComponent(filename)
                if let existing = try? Data(contentsOf: destination) {
                    previousPhotoBytes[filename] = existing
                }
                try imageBytes.write(to: destination, options: .atomic)
                writtenPhotoNames.insert(filename)
            }
            data = incoming
            guard persist() else { throw ImportError.saveFailed }
        } catch {
            data = previous
            for filename in writtenPhotoNames {
                let destination = imagesURL.appendingPathComponent(filename)
                if let oldBytes = previousPhotoBytes[filename] {
                    try? oldBytes.write(to: destination, options: .atomic)
                } else {
                    try? FileManager.default.removeItem(at: destination)
                }
            }
            throw error
        }
        previousItemIDs.subtracting(itemIDs).forEach { ReminderService.cancel(itemID: $0) }
        items.forEach { ReminderService.schedule(item: $0, leadDays: data.reminderLeadDays) }
        previousPhotoNames.subtracting(referencedPhotos).forEach {
            try? FileManager.default.removeItem(at: imagesURL.appendingPathComponent($0))
        }
    }

    @discardableResult
    private func persist() -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(data).write(to: fileURL, options: .atomic)
            lastSaveError = nil
            return true
        } catch {
            lastSaveError = "Changes couldn't be saved on this device. Check available storage."
            return false
        }
    }

    @discardableResult
    private func commit(_ mutation: (inout PassportData) -> Void) -> Bool {
        let previous = data
        mutation(&data)
        guard persist() else {
            data = previous
            return false
        }
        return true
    }

    private func restoreImage(at url: URL?, previousBytes: Data?) {
        guard let url else { return }
        if let previousBytes {
            try? previousBytes.write(to: url, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func csvField(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    enum ImportError: LocalizedError {
        case noHomes, invalidHomeLink, invalidItemLink, invalidPhoto, saveFailed
        var errorDescription: String? { "This backup is incomplete or damaged." }
    }
}

private extension UIImage {
    func preparingForLocalStorage(maxPixelDimension: CGFloat) -> UIImage {
        let largestSide = max(size.width, size.height)
        guard largestSide > maxPixelDimension else { return self }
        let scale = maxPixelDimension / largestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: targetSize).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private struct PassportBackup: Codable {
    let data: PassportData
    let photos: [String: Data]
}
