import SwiftUI
import SwiftData
import OSLog

/// TS1 — three radio rows on a Form. Replaces the previous full-width radio
/// cards. The data shape is "pick one of three"; the form pattern says that.
struct ThemeSettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext

    private let logger = Logger(subsystem: "com.stackspeak.ios", category: "Settings")

    private let options: [(ThemePreference, LocalizedStringKey, LocalizedStringKey)] = [
        (.system, "settings.theme.system", "settings.theme.systemDesc"),
        (.light,  "settings.theme.light",  "settings.theme.lightDesc"),
        (.dark,   "settings.theme.dark",   "settings.theme.darkDesc")
    ]

    var body: some View {
        Form {
            Section {
                ForEach(options, id: \.0) { preference, labelKey, descKey in
                    optionRow(preference: preference, labelKey: labelKey, descKey: descKey)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.colors.bg)
        .navigationTitle("settings.theme.navTitle")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func optionRow(
        preference: ThemePreference,
        labelKey: LocalizedStringKey,
        descKey: LocalizedStringKey
    ) -> some View {
        let isSelected = theme.preference == preference
        return Button(action: { apply(preference) }) {
            HStack(spacing: theme.spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(labelKey)
                        .font(TypographyTokens.body)
                        .foregroundColor(theme.colors.ink)
                    Text(descKey)
                        .font(TypographyTokens.footnote)
                        .foregroundColor(theme.colors.inkMuted)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(.callout, weight: .semibold))
                        .foregroundColor(theme.colors.accent)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(labelKey)
        .accessibilityValue(isSelected ? "selected" : "not selected")
    }

    private func apply(_ preference: ThemePreference) {
        theme.preference = preference
        userProgress?.themePreference = preference
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save theme preference: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#Preview("Theme Settings - Light") {
    NavigationStack {
        ThemeSettingsView()
            .withTheme(ThemeManager())
    }
}

#Preview("Theme Settings - Dark") {
    NavigationStack {
        ThemeSettingsView()
            .withTheme(ThemeManager())
            .preferredColorScheme(.dark)
    }
}
