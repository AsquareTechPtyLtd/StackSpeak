import SwiftUI

/// One selectable subscription option on the Pro paywall. Takes plain display
/// values (not a StoreKit `Product`, which has no public init) so it stays
/// previewable; `Product.paywallPriceText`/`paywallTrialText` derive the copy.
struct ProProductCard: View {
    @Environment(\.theme) private var theme

    let title: String
    let priceText: String
    let trialText: String?
    let isSelected: Bool
    let isBestValue: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: theme.spacing.md) {
                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    HStack(spacing: theme.spacing.sm) {
                        Text(title)
                            .font(TypographyTokens.headline)
                            .foregroundColor(theme.colors.ink)
                        if isBestValue {
                            Text("pro.gate.bestValue")
                                .font(TypographyTokens.caption.weight(.semibold))
                                .foregroundColor(theme.colors.accent)
                                .padding(.horizontal, theme.spacing.sm)
                                .padding(.vertical, theme.spacing.xxs)
                                .background(theme.colors.accentBg)
                                .clipShape(Capsule())
                        }
                    }

                    Text(priceText)
                        .font(TypographyTokens.footnote)
                        .foregroundColor(theme.colors.inkMuted)

                    if let trialText {
                        Text(trialText)
                            .font(TypographyTokens.caption.weight(.medium))
                            .foregroundColor(theme.colors.accent)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(.title2))
                    .foregroundColor(isSelected ? theme.colors.accent : theme.colors.inkFaint)
            }
            .padding(theme.spacing.cardPadding)
            .background(isSelected ? theme.colors.accentBg : theme.colors.surface)
            .clipShape(.rect(cornerRadius: RadiusTokens.card))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .stroke(
                        isSelected ? theme.colors.accent : theme.colors.line,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(title), \(priceText)"))
        .accessibilityValue(isSelected ? "selected" : "not selected")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Previews

#Preview("Pro Product Card - Light") {
    VStack(spacing: 12) {
        ProProductCard(title: "Pro Monthly", priceText: "$2.99 / month",
                       trialText: "7 days free", isSelected: false,
                       isBestValue: false, onSelect: {})
        ProProductCard(title: "Pro Yearly", priceText: "$19.99 / year",
                       trialText: "7 days free", isSelected: true,
                       isBestValue: true, onSelect: {})
    }
    .padding()
    .withTheme(ThemeManager())
}

#Preview("Pro Product Card - Dark") {
    VStack(spacing: 12) {
        ProProductCard(title: "Pro Monthly", priceText: "$2.99 / month",
                       trialText: "7 days free", isSelected: false,
                       isBestValue: false, onSelect: {})
        ProProductCard(title: "Pro Yearly", priceText: "$19.99 / year",
                       trialText: "7 days free", isSelected: true,
                       isBestValue: true, onSelect: {})
    }
    .padding()
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}
