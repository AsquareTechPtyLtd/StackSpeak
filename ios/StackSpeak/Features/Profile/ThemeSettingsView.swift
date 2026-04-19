import SwiftUI
import SwiftData
import OSLog

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
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: theme.spacing.sm) {
                    ForEach(options, id: \.0) { preference, labelKey, descKey in
                        optionRow(
                            preference: preference,
                            labelKey: labelKey,
                            descKey: descKey
                        )
                    }
                }
                .frame(maxWidth: 720)
                .padding(theme.spacing.lg)
            }
        }
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
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text(labelKey)
                        .font(TypographyTokens.headline)
                        .foregroundColor(theme.colors.ink)
                    Text(descKey)
                        .font(TypographyTokens.callout)
                        .foregroundColor(theme.colors.inkMuted)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? theme.colors.accent : theme.colors.inkFaint)
                    .accessibilityHidden(true)
            }
            .padding(theme.spacing.cardPadding(density: theme.density))
            .background(theme.colors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? theme.colors.accent : theme.colors.line,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
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
            logger.error("Failed to save theme preference: \(error.localizedDescription)")
        }
    }
}

#Preview("Theme Settings - Light") {
    ThemeSettingsView()
        .withTheme(ThemeManager())
}

#Preview("Theme Settings - Dark") {
    ThemeSettingsView()
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
