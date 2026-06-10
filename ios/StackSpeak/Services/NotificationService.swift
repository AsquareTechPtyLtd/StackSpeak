import Foundation
import UserNotifications

@MainActor
final class NotificationService: NotificationRepository {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    private let notificationMessages = [
        String(localized: "notification.body.1"),
        String(localized: "notification.body.2"),
        String(localized: "notification.body.3"),
        String(localized: "notification.body.4"),
        String(localized: "notification.body.5")
    ]

    init() {}

    func requestAuthorization() async throws -> Bool {
        let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        return granted
    }

    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    func scheduleDailyNotifications(at time: Date, isPrimary: Bool = true, count: Int = 7) async throws {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        let prefix = isPrimary ? "daily-reminder" : "second-reminder"

        // Schedule N one-shot notifications, rotating through messages
        for dayOffset in 0..<count {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: Date()),
                  let scheduledDate = calendar.date(bySettingHour: timeComponents.hour ?? 9,
                                                     minute: timeComponents.minute ?? 0,
                                                     second: 0,
                                                     of: targetDate) else { continue }

            // Skip a day-0 slot whose time has already passed: a calendar trigger
            // with a past date fires at the NEXT matching time (tomorrow), which
            // would silently collide with day 1's slot under today's identifier.
            guard scheduledDate > Date() else { continue }

            let dateString = DateFormatter.yyyyMMdd.string(from: scheduledDate)
            let content = UNMutableNotificationContent()
            content.title = String(localized: "notification.title")
            content.body = notificationMessages[dayOffset % notificationMessages.count]
            content.sound = .default
            content.badge = 1

            let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(identifier: "\(prefix)-\(dateString)", content: content, trigger: trigger)

            try await notificationCenter.add(request)
        }
    }

    func cancelNotification(identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    func rescheduleNotifications(primary: Date?, secondary: Date?) async throws {
        cancelAllNotifications()

        if let primary = primary {
            try await scheduleDailyNotifications(at: primary, isPrimary: true)
        }

        if let secondary = secondary {
            try await scheduleDailyNotifications(at: secondary, isPrimary: false)
        }
    }

    func getPendingNotificationCount() async -> Int {
        let pending = await notificationCenter.pendingNotificationRequests()
        return pending.count
    }

    func resetBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}

// MARK: - Helpers

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
