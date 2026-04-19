import SwiftUI
import SwiftData
import OSLog

struct DensitySettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext

    private let logger = Logger(subsystem: "com.stackspeak.ios", category: "Settings")

    private let options: [(DensityPreference, LocalizedStringKey, LocalizedStringKey)] = [
        (.compact, "settings.density.compact", "settings.density.compactDesc"),
        (.roomy,   "settings.density.roomy",   "settings.density.roomyDesc")
    ]

    var body: some View {
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: theme.spacing.sm) {
                    ForEach(options, id: \.0) { density, labelKey, descKey in
                        optionRow(
                            density: density,
                            labelKey: labelKey,
                            descKey: descKey
                        )
                    }
                }
                .frame(maxWidth: 720)
                .padding(theme.spacing.lg)
            }
        }
        .navigationTitle("settings.density.navTitle")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func optionRow(
        density: DensityPreference,
        labelKey: LocalizedStringKey,
        descKey: LocalizedStringKey
    ) -> some View {
        let isSelected = theme.density == density
        return Button(action: { apply(density) }) {
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

    private func apply(_ density: DensityPreference) {
        theme.density = density
        userProgress?.densityPreference = density
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save density preference: \(error.localizedDescription)")
        }
    }
}

#Preview("Density Settings - Light") {
    DensitySettingsView()
        .withTheme(ThemeManager())
}

#Preview("Density Settings - Dark") {
    DensitySettingsView()
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
