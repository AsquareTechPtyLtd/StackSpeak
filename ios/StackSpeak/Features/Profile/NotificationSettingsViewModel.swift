import Foundation
import SwiftData
import UserNotifications
import OSLog

/// Business logic for the notification settings form: authorization state,
/// schedule-then-save transactions, and revert-on-failure reconciliation.
/// Extracted from the view so the revert logic is unit-testable; the
/// notification scheduler is injected via `NotificationRepository`.
@MainActor
@Observable
final class NotificationSettingsViewModel {
    var authStatus: UNAuthorizationStatus = .notDetermined
    var primaryTime: Date
    var secondTime: Date
    var errorMessage: String?

    private let notifications: any NotificationRepository
    private let logger = Logger(category: "Settings")

    init(notifications: any NotificationRepository = NotificationService.shared) {
        self.notifications = notifications
        self.primaryTime = Self.defaultPrimaryTime
        self.secondTime = Self.defaultSecondTime
    }

    static var defaultPrimaryTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }

    static var defaultSecondTime: Date {
        Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    }

    func loadInitialState(userProgress: UserProgress?) async {
        authStatus = await notifications.checkAuthorizationStatus()
        guard let progress = userProgress else { return }
        primaryTime = progress.notificationTime ?? Self.defaultPrimaryTime
        secondTime  = progress.secondReminderTime ?? Self.defaultSecondTime
    }

    // The desired OS schedule derived from the (possibly just-mutated) model.
    // `rescheduleNotifications(nil, nil)` cancels everything, which is exactly
    // what we want when notifications are off.
    private func desiredPrimary(_ progress: UserProgress) -> Date? {
        progress.notificationEnabled ? (progress.notificationTime ?? primaryTime) : nil
    }

    private func desiredSecondary(_ progress: UserProgress) -> Date? {
        (progress.notificationEnabled && progress.secondReminderEnabled)
            ? (progress.secondReminderTime ?? secondTime)
            : nil
    }

    /// Schedules notifications to match the already-mutated model, then persists
    /// only if scheduling succeeded. On failure the in-memory change is reverted
    /// and the OS is reconciled back to the last-saved settings — so the database
    /// is never saved into a state iOS doesn't actually reflect, and we never
    /// leave a partially-scheduled set behind.
    private func scheduleThenSave(
        progress: UserProgress,
        modelContext: ModelContext,
        revert: () -> Void
    ) async {
        do {
            try await notifications.rescheduleNotifications(
                primary: desiredPrimary(progress),
                secondary: desiredSecondary(progress)
            )
            try modelContext.save()
        } catch {
            logger.error("Failed to schedule/save notifications: \(error.localizedDescription, privacy: .public)")
            revert()
            // Best-effort reconcile to the reverted (last-saved) settings.
            try? await notifications.rescheduleNotifications(
                primary: desiredPrimary(progress),
                secondary: desiredSecondary(progress)
            )
            errorMessage = error.localizedDescription
        }
    }

    func toggleNotifications(_ enabled: Bool, userProgress: UserProgress?, modelContext: ModelContext) async {
        guard let progress = userProgress else { return }

        if enabled {
            do {
                let granted = try await notifications.requestAuthorization()
                authStatus = await notifications.checkAuthorizationStatus()
                guard granted else { return }
            } catch {
                authStatus = await notifications.checkAuthorizationStatus()
                return
            }
            progress.notificationEnabled = true
            progress.notificationTime = primaryTime
            await scheduleThenSave(progress: progress, modelContext: modelContext) {
                progress.notificationEnabled = false
            }
        } else {
            let wasSecondEnabled = progress.secondReminderEnabled
            progress.notificationEnabled = false
            progress.secondReminderEnabled = false
            await scheduleThenSave(progress: progress, modelContext: modelContext) {
                progress.notificationEnabled = true
                progress.secondReminderEnabled = wasSecondEnabled
            }
        }
    }

    func savePrimaryTime(_ time: Date, userProgress: UserProgress?, modelContext: ModelContext) async {
        guard let progress = userProgress else { return }
        let oldTime = progress.notificationTime
        progress.notificationTime = time
        await scheduleThenSave(progress: progress, modelContext: modelContext) {
            progress.notificationTime = oldTime
        }
    }

    func toggleSecondReminder(_ enabled: Bool, userProgress: UserProgress?, modelContext: ModelContext) async {
        guard let progress = userProgress else { return }
        let wasEnabled = progress.secondReminderEnabled
        let oldTime = progress.secondReminderTime
        progress.secondReminderEnabled = enabled
        if enabled {
            progress.secondReminderTime = secondTime
        }
        await scheduleThenSave(progress: progress, modelContext: modelContext) {
            progress.secondReminderEnabled = wasEnabled
            progress.secondReminderTime = oldTime
        }
    }

    func saveSecondTime(_ time: Date, userProgress: UserProgress?, modelContext: ModelContext) async {
        guard let progress = userProgress, progress.secondReminderEnabled else { return }
        let oldTime = progress.secondReminderTime
        progress.secondReminderTime = time
        await scheduleThenSave(progress: progress, modelContext: modelContext) {
            progress.secondReminderTime = oldTime
        }
    }
}
