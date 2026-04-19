import SwiftUI
import SwiftData
import UserNotifications
import OSLog

struct NotificationSettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    private let logger = Logger(subsystem: "com.stackspeak.ios", category: "Settings")

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
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: theme.spacing.lg) {
                    if authStatus == .denied {
                        permissionDeniedBanner
                    }

                    primaryToggleCard

                    if let progress = userProgress,
                       progress.notificationEnabled,
                       authStatus == .authorized {
                        primaryTimeCard
                        secondReminderCard
                    }
                }
                .frame(maxWidth: 720)
                .padding(theme.spacing.lg)
            }
        }
        .navigationTitle("settings.notifications.navTitle")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadInitialState()
        }
    }

    // MARK: - Subviews

    private var permissionDeniedBanner: some View {
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
            .padding(theme.spacing.md)
            .background(theme.colors.warn.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "settings.notifications.permissionDenied"))
        .accessibilityHint("Opens iOS Settings")
    }

    private var primaryToggleCard: some View {
        HStack(spacing: theme.spacing.md) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text("settings.notifications.enable")
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.ink)
                Text("settings.notifications.enableDesc")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { userProgress?.notificationEnabled ?? false },
                set: { enabled in toggleNotifications(enabled) }
            ))
            .tint(theme.colors.accent)
            .labelsHidden()
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private var primaryTimeCard: some View {
        HStack {
            Text("settings.notifications.primaryTime")
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.ink)
            Spacer()
            DatePicker(
                "",
                selection: $primaryTime,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .onChange(of: primaryTime) { _, newValue in
                savePrimaryTime(newValue)
            }
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private var secondReminderCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: theme.spacing.md) {
                Text("settings.notifications.secondReminder")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.ink)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { userProgress?.secondReminderEnabled ?? false },
                    set: { enabled in toggleSecondReminder(enabled) }
                ))
                .tint(theme.colors.accent)
                .labelsHidden()
            }
            .padding(theme.spacing.cardPadding(density: theme.density))

            if let progress = userProgress, progress.secondReminderEnabled {
                Divider().background(theme.colors.line)

                HStack {
                    Text("settings.notifications.secondTime")
                        .font(TypographyTokens.callout)
                        .foregroundColor(theme.colors.ink)
                    Spacer()
                    DatePicker(
                        "",
                        selection: $secondTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .onChange(of: secondTime) { _, newValue in
                        saveSecondTime(newValue)
                    }
                }
                .padding(theme.spacing.cardPadding(density: theme.density))
            }
        }
        .background(theme.colors.surface)
        .cornerRadius(12)
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
                        logger.error("Failed to save notification enabled: \(error.localizedDescription)")
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
                logger.error("Failed to save notification disabled: \(error.localizedDescription)")
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
            logger.error("Failed to save primary notification time: \(error.localizedDescription)")
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
            logger.error("Failed to save second reminder toggle: \(error.localizedDescription)")
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
            logger.error("Failed to save second notification time: \(error.localizedDescription)")
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
