import SwiftUI

/// Minimal pro-upsell gate shown when a free user taps "Get Pro" on the core
/// stacks section. Replace with a full subscription flow when IAP is wired up.
struct ProGateSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: theme.spacing.lg) {
                ZStack {
                    Circle()
                        .fill(theme.colors.accentBg)
                        .frame(width: IconSizeTokens.avatar, height: IconSizeTokens.avatar)
                    Image(systemName: "star.fill")
                        .scaledIcon(size: IconSizeTokens.avatar * 0.45, weight: .semibold)
                        .foregroundColor(theme.colors.accent)
                }
                .accessibilityHidden(true)

                VStack(spacing: theme.spacing.sm) {
                    Text("pro.gate.title")
                        .font(TypographyTokens.title2)
                        .foregroundColor(theme.colors.ink)
                        .multilineTextAlignment(.center)

                    Text("pro.gate.message")
                        .font(TypographyTokens.body)
                        .foregroundColor(theme.colors.inkMuted)
                        .multilineTextAlignment(.center)
                }

                PrimaryCTAButton("pro.gate.cta") { dismiss() }

                devProToggle
            }
            .padding(theme.spacing.xl)

            Spacer()
        }
        .background(theme.colors.bg.ignoresSafeArea())
    }

    /// Same dev affordance shown on `BookLockedSheet`. Lets a tester unlock all
    /// Pro features without an IAP. Strings are shared (`books.dev.proToggle*`)
    /// because the copy applies equally to either gate.
    private var devProToggle: some View {
        HStack(spacing: theme.spacing.sm) {
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text("books.dev.proToggle")
                    .font(TypographyTokens.footnote.weight(.medium))
                    .foregroundColor(theme.colors.inkMuted)
                Text("books.dev.proToggle.subtitle")
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkFaint)
            }
            Spacer()
            #if DEBUG
            Toggle("", isOn: Binding(
                get: { userProgress?.isProActive ?? false },
                set: { on in
                    guard let progress = userProgress else { return }
                    // Capture pre-toggle state so a failed save restores BOTH
                    // fields — nil-ing the expiry on revert would strand a
                    // restored isPro=true with no expiry date.
                    let oldIsPro = progress.isPro
                    let oldExpiry = progress.proExpiryDate
                    progress.isPro = on
                    progress.proExpiryDate = on
                        ? Calendar.current.date(byAdding: .year, value: 1, to: Date())
                        : nil
                    do {
                        try modelContext.save()
                        if on { dismiss() }
                    } catch {
                        progress.isPro = oldIsPro
                        progress.proExpiryDate = oldExpiry
                    }
                }
            ))
            .labelsHidden()
            #endif
        }
        .padding(theme.spacing.md)
        .background(theme.colors.surfaceAlt)
        .clipShape(.rect(cornerRadius: RadiusTokens.inline))
    }
}

#Preview("Pro Gate Sheet - Light") {
    ProGateSheet().withTheme(ThemeManager())
}

#Preview("Pro Gate Sheet - Dark") {
    ProGateSheet()
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
