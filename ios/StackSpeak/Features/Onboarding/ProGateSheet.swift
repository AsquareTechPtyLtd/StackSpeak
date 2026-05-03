import SwiftUI

/// Minimal pro-upsell gate shown when a free user taps "Get Pro" on the core
/// stacks section. Replace with a full subscription flow when IAP is wired up.
struct ProGateSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: theme.spacing.lg) {
                ZStack {
                    Circle()
                        .fill(theme.colors.accentBg)
                        .frame(width: 80, height: 80)
                    Image(systemName: "star.fill")
                        .font(.system(size: 36, weight: .semibold))
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
            }
            .padding(theme.spacing.xl)

            Spacer()
        }
        .background(theme.colors.bg.ignoresSafeArea())
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
