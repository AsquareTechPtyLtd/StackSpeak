import Testing
import Foundation
import SwiftData
import UserNotifications
@testable import StackSpeak

@Suite("NotificationSettingsViewModel Tests")
@MainActor
struct NotificationSettingsViewModelTests {

    /// Mock scheduler — records calls and can be told to fail rescheduling.
    final class MockNotificationRepository: NotificationRepository {
        var shouldFailReschedule = false
        var rescheduleCalls: [(primary: Date?, secondary: Date?)] = []
        var authorizationGranted = true

        func requestAuthorization() async throws -> Bool { authorizationGranted }
        func checkAuthorizationStatus() async -> UNAuthorizationStatus {
            authorizationGranted ? .authorized : .denied
        }
        func scheduleDailyNotifications(at time: Date, isPrimary: Bool, count: Int) async throws {}
        func rescheduleNotifications(primary: Date?, secondary: Date?) async throws {
            rescheduleCalls.append((primary, secondary))
            if shouldFailReschedule {
                throw NSError(domain: "test", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "scheduling failed"])
            }
        }
        func cancelNotification(identifier: String) {}
        func cancelAllNotifications() {}
        func getPendingNotificationCount() async -> Int { 0 }
        func resetBadge() {}
    }

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: UserProgress.self, configurations: config)
    }

    @Test("savePrimaryTime persists the new time when scheduling succeeds")
    func savePrimaryTimeSuccess() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let progress = UserProgress()
        progress.notificationEnabled = true
        context.insert(progress)

        let mock = MockNotificationRepository()
        let viewModel = NotificationSettingsViewModel(notifications: mock)

        let newTime = Date(timeIntervalSince1970: 1_700_000_000)
        await viewModel.savePrimaryTime(newTime, userProgress: progress, modelContext: context)

        #expect(progress.notificationTime == newTime)
        #expect(viewModel.errorMessage == nil)
        #expect(mock.rescheduleCalls.count == 1)
    }

    @Test("savePrimaryTime reverts the model and reconciles the OS on failure")
    func savePrimaryTimeRevertsOnFailure() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let progress = UserProgress()
        progress.notificationEnabled = true
        let oldTime = Date(timeIntervalSince1970: 1_600_000_000)
        progress.notificationTime = oldTime
        context.insert(progress)

        let mock = MockNotificationRepository()
        mock.shouldFailReschedule = true
        let viewModel = NotificationSettingsViewModel(notifications: mock)

        await viewModel.savePrimaryTime(
            Date(timeIntervalSince1970: 1_700_000_000),
            userProgress: progress, modelContext: context)

        #expect(progress.notificationTime == oldTime)   // reverted
        #expect(viewModel.errorMessage != nil)          // surfaced
        #expect(mock.rescheduleCalls.count == 2)        // attempt + reconcile
    }

    @Test("toggleSecondReminder revert restores both the flag and the old time")
    func toggleSecondReminderRevertsBothFields() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let progress = UserProgress()
        progress.notificationEnabled = true
        progress.secondReminderEnabled = false
        progress.secondReminderTime = nil
        context.insert(progress)

        let mock = MockNotificationRepository()
        mock.shouldFailReschedule = true
        let viewModel = NotificationSettingsViewModel(notifications: mock)

        await viewModel.toggleSecondReminder(true, userProgress: progress, modelContext: context)

        #expect(progress.secondReminderEnabled == false)
        #expect(progress.secondReminderTime == nil)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("disabling notifications also disables the second reminder, and revert restores it")
    func toggleOffRevertRestoresSecondReminder() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let progress = UserProgress()
        progress.notificationEnabled = true
        progress.secondReminderEnabled = true
        context.insert(progress)

        let mock = MockNotificationRepository()
        mock.shouldFailReschedule = true
        let viewModel = NotificationSettingsViewModel(notifications: mock)

        await viewModel.toggleNotifications(false, userProgress: progress, modelContext: context)

        // Failure path: everything restored to pre-toggle state.
        #expect(progress.notificationEnabled == true)
        #expect(progress.secondReminderEnabled == true)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("toggling on without authorization makes no model change")
    func toggleOnDeniedAuthorization() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let progress = UserProgress()
        progress.notificationEnabled = false
        context.insert(progress)

        let mock = MockNotificationRepository()
        mock.authorizationGranted = false
        let viewModel = NotificationSettingsViewModel(notifications: mock)

        await viewModel.toggleNotifications(true, userProgress: progress, modelContext: context)

        #expect(progress.notificationEnabled == false)
        #expect(viewModel.authStatus == .denied)
        #expect(mock.rescheduleCalls.isEmpty)
    }
}
