import SwiftUI
import SwiftData
import UserNotifications
import OSLog

/// NS1 — Form-shaped data presented as a Form. The previous nested-cards
/// layout was hand-rolling exactly what `Form { Section { ... } }` does for
/// free, with worse a11y and worse Dynamic Type behavior.
struct NotificationSettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    private let logger = Logger(category: "Settings")

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var primaryTime: Date = Self.defaultPrimaryTime
    @State private var secondTime: Date = Self.defaultSecondTime

    private static var defaultPrimaryTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private static var defaultSecondTime: Date {
        Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    }

    var body: some View {
        Form {
            if authStatus == .denied {
                Section { permissionDeniedRow }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { userProgress?.notificationEnabled ?? false },
                    set: { toggleNotifications($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.notifications.enable")
                            .font(TypographyTokens.body)
                            .foregroundColor(theme.colors.ink)
                        Text("settings.notifications.enableDesc")
                            .font(TypographyTokens.footnote)
                            .foregroundColor(theme.colors.inkMuted)
                    }
                }
                .tint(theme.colors.accent)
            }

            if let progress = userProgress, progress.notificationEnabled, authStatus == .authorized {
                Section {
                    DatePicker(
                        selection: $primaryTime,
                        displayedComponents: .hourAndMinute
                    ) {
                        Text("settings.notifications.primaryTime")
                            .font(TypographyTokens.body)
                            .foregroundColor(theme.colors.ink)
                    }
                    .onChange(of: primaryTime) { _, newValue in savePrimaryTime(newValue) }
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { userProgress?.secondReminderEnabled ?? false },
                        set: { toggleSecondReminder($0) }
                    )) {
                        Text("settings.notifications.secondReminder")
                            .font(TypographyTokens.body)
                            .foregroundColor(theme.colors.ink)
                    }
                    .tint(theme.colors.accent)

                    if progress.secondReminderEnabled {
                        DatePicker(
                            selection: $secondTime,
                            displayedComponents: .hourAndMinute
                        ) {
                            Text("settings.notifications.secondTime")
                                .font(TypographyTokens.body)
                                .foregroundColor(theme.colors.ink)
                        }
                        .onChange(of: secondTime) { _, newValue in saveSecondTime(newValue) }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.colors.bg)
        .navigationTitle("settings.notifications.navTitle")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadInitialState() }
    }

    private var permissionDeniedRow: some View {
        Button(action: openAppSettings) {
            HStack(spacing: theme.spacing.md) {
                Image(systemName: "bell.slash.fill")
                    .foregroundColor(theme.colors.warn)
                    .accessibilityHidden(true)
                Text("settings.notifications.permissionDenied")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.ink)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(theme.colors.inkMuted)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "settings.notifications.permissionDenied"))
        .accessibilityHint("Opens iOS Settings")
    }

    // MARK: - Actions

    private func loadInitialState() async {
        authStatus = await NotificationService.shared.checkAuthorizationStatus()
        guard let progress = userProgress else { return }
        primaryTime = progress.notificationTime ?? Self.defaultPrimaryTime
        secondTime  = progress.secondReminderTime ?? Self.defaultSecondTime
    }

    private func toggleNotifications(_ enabled: Bool) {
        guard let progress = userProgress else { return }

        if enabled {
            Task {
                do {
                    let granted = try await NotificationService.shared.requestAuthorization()
                    authStatus = await NotificationService.shared.checkAuthorizationStatus()
                    guard granted else { return }

                    progress.notificationEnabled = true
                    progress.notificationTime = primaryTime
                    do {
                        try modelContext.save()
                    } catch {
                        logger.error("Failed to save notification enabled: \(error.localizedDescription, privacy: .public)")
                    }
                    try await NotificationService.shared.rescheduleNotifications(
                        primary: primaryTime,
                        secondary: progress.secondReminderEnabled ? secondTime : nil
                    )
                } catch {
                    authStatus = await NotificationService.shared.checkAuthorizationStatus()
                }
            }
        } else {
            progress.notificationEnabled = false
            progress.secondReminderEnabled = false
            do {
                try modelContext.save()
            } catch {
                logger.error("Failed to save notification disabled: \(error.localizedDescription, privacy: .public)")
            }
            NotificationService.shared.cancelAllNotifications()
        }
    }

    private func savePrimaryTime(_ time: Date) {
        guard let progress = userProgress else { return }
        progress.notificationTime = time
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save primary notification time: \(error.localizedDescription, privacy: .public)")
        }
        Task {
            try? await NotificationService.shared.rescheduleNotifications(
                primary: time,
                secondary: progress.secondReminderEnabled ? secondTime : nil
            )
        }
    }

    private func toggleSecondReminder(_ enabled: Bool) {
        guard let progress = userProgress else { return }
        progress.secondReminderEnabled = enabled
        if enabled {
            progress.secondReminderTime = secondTime
        }
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save second reminder toggle: \(error.localizedDescription, privacy: .public)")
        }
        Task {
            try? await NotificationService.shared.rescheduleNotifications(
                primary: progress.notificationEnabled ? primaryTime : nil,
                secondary: enabled ? secondTime : nil
            )
        }
    }

    private func saveSecondTime(_ time: Date) {
        guard let progress = userProgress, progress.secondReminderEnabled else { return }
        progress.secondReminderTime = time
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save second notification time: \(error.localizedDescription, privacy: .public)")
        }
        Task {
            try? await NotificationService.shared.rescheduleNotifications(
                primary: progress.notificationEnabled ? primaryTime : nil,
                secondary: time
            )
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}
