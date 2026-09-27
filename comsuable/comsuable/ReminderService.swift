import Foundation
import UserNotifications

enum NotificationPermissionState: Equatable {
    case notRequested
    case allowed
    case denied

    init(status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notRequested
        case .authorized, .provisional, .ephemeral:
            self = .allowed
        case .denied:
            self = .denied
        @unknown default:
            self = .denied
        }
    }

    var displayName: String {
        switch self {
        case .notRequested: "Not requested"
        case .allowed: "Allowed"
        case .denied: "Not allowed"
        }
    }
}

enum ReminderService {
    static func authorizationState() async -> NotificationPermissionState {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return NotificationPermissionState(status: settings.authorizationStatus)
    }

    static func requestAuthorization() async throws -> NotificationPermissionState {
        let currentState = await authorizationState()
        guard currentState == .notRequested else { return currentState }
        _ = try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
        return await authorizationState()
    }

    static func schedule(item: ConsumableItem, leadDays: Int) {
        cancel(itemID: item.id)
        guard item.remindersEnabled,
              let alertDate = notificationDate(for: item, leadDays: leadDays) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time to check \(item.name)"
        content.body = "\(item.brand.isEmpty ? item.name : item.brand) · \(item.model.isEmpty ? item.size : item.model) is due soon."
        content.sound = .default
        content.userInfo = ["itemID": item.id.uuidString]
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: alertDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)
        )
    }

    static func cancel(itemID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [itemID.uuidString])
    }

    static func notificationDate(
        for item: ConsumableItem,
        leadDays: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard let dueDate = item.nextDueDate,
              let reminderDay = calendar.date(byAdding: .day, value: -leadDays, to: dueDate) else {
            return nil
        }
        let day = calendar.dateComponents([.year, .month, .day], from: reminderDay)
        guard let atNine = calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: day.year,
                month: day.month,
                day: day.day,
                hour: 9,
                minute: 0
            )
        ), atNine > now else { return nil }
        return atNine
    }
}
