import SwiftUI
import SwiftData
import UserNotifications

/// NS1 — Form-shaped data presented as a Form. The previous nested-cards
/// layout was hand-rolling exactly what `Form { Section { ... } }` does for
/// free, with worse a11y and worse Dynamic Type behavior.
/// Pure presentation — scheduling/persistence logic lives in
/// `NotificationSettingsViewModel`.
struct NotificationSettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @State private var viewModel = NotificationSettingsViewModel()

    var body: some View {
        Form {
            if viewModel.authStatus == .denied {
                Section { permissionDeniedRow }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { userProgress?.notificationEnabled ?? false },
                    set: { enabled in
                        Task { await viewModel.toggleNotifications(enabled, userProgress: userProgress, modelContext: modelContext) }
                    }
                )) {
                    VStack(alignment: .leading, spacing: theme.spacing.xxs) {
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

            if let progress = userProgress, progress.notificationEnabled, viewModel.authStatus == .authorized {
                Section {
                    DatePicker(
                        selection: $viewModel.primaryTime,
                        displayedComponents: .hourAndMinute
                    ) {
                        Text("settings.notifications.primaryTime")
                            .font(TypographyTokens.body)
                            .foregroundColor(theme.colors.ink)
                    }
                    .onChange(of: viewModel.primaryTime) { _, newValue in
                        Task { await viewModel.savePrimaryTime(newValue, userProgress: userProgress, modelContext: modelContext) }
                    }
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { userProgress?.secondReminderEnabled ?? false },
                        set: { enabled in
                            Task { await viewModel.toggleSecondReminder(enabled, userProgress: userProgress, modelContext: modelContext) }
                        }
                    )) {
                        Text("settings.notifications.secondReminder")
                            .font(TypographyTokens.body)
                            .foregroundColor(theme.colors.ink)
                    }
                    .tint(theme.colors.accent)

                    if progress.secondReminderEnabled {
                        DatePicker(
                            selection: $viewModel.secondTime,
                            displayedComponents: .hourAndMinute
                        ) {
                            Text("settings.notifications.secondTime")
                                .font(TypographyTokens.body)
                                .foregroundColor(theme.colors.ink)
                        }
                        .onChange(of: viewModel.secondTime) { _, newValue in
                            Task { await viewModel.saveSecondTime(newValue, userProgress: userProgress, modelContext: modelContext) }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.colors.bg)
        .navigationTitle("settings.notifications.navTitle")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            Text("saveError.title"),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            presenting: viewModel.errorMessage
        ) { _ in
            Button("common.ok") { viewModel.errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
        .task { await viewModel.loadInitialState(userProgress: userProgress) }
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
        .accessibilityHint(String(localized: "a11y.opensSystemSettings"))
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

#Preview("Notification Settings — Light") {
    NavigationStack { NotificationSettingsView() }
        .withTheme(ThemeManager())
}

#Preview("Notification Settings — Dark") {
    NavigationStack { NotificationSettingsView() }
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
