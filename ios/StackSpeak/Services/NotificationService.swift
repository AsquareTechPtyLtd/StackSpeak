import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    private let notificationMessages = [
        "5 new words are waiting.",
        "Keep your streak alive — today's words are ready.",
        "Time to level up your vocabulary.",
        "Your daily words are here.",
        "Ready to learn? Today's words await."
    ]

    private init() {}

    func requestAuthorization() async throws -> Bool {
        let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        return granted
    }

    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    func scheduleDailyNotification(at time: Date, isPrimary: Bool = true) async throws {
        let content = UNMutableNotificationContent()
        content.title = "StackSpeak"
        content.body = notificationMessages.randomElement() ?? notificationMessages[0]
        content.sound = .default
        content.badge = 1

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let identifier = isPrimary ? "daily-reminder" : "second-reminder"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await notificationCenter.add(request)
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
            try await scheduleDailyNotification(at: primary, isPrimary: true)
        }

        if let secondary = secondary {
            try await scheduleDailyNotification(at: secondary, isPrimary: false)
        }
    }

    func resetBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
