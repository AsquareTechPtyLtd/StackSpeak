import SwiftUI

/// Selection chrome shared by SelectableRow, StackCard, ProProductCard, and
/// OptionButton: padded fill, rounded card, hairline border that thickens and
/// tints when selected. One implementation so the four call sites can't drift.
struct SelectableCardChrome: ViewModifier {
    @Environment(\.theme) private var theme

    let isSelected: Bool
    /// Override for state-colored fills (e.g. OptionButton's correct/incorrect
    /// tints). Defaults to accentBg-when-selected over surface.
    var fill: Color?
    /// Override for state-colored borders. Defaults to accent-when-selected
    /// over the hairline `line` color.
    var border: Color?
    /// Defaults to the card padding; OptionButton and the category chips use
    /// their own insets.
    var padding: EdgeInsets?
    /// Card radius for rows/cards; chips pass `RadiusTokens.pill`.
    var radius: CGFloat = RadiusTokens.card
    /// Resting border width; chips use `regular` instead of the hairline.
    var idleLineWidth: CGFloat = BorderTokens.hairline

    func body(content: Content) -> some View {
        let resolvedFill: Color = fill ?? (isSelected ? theme.colors.accentBg : theme.colors.surface)
        let resolvedBorder: Color = border ?? (isSelected ? theme.colors.accent : theme.colors.line)
        let lineWidth: CGFloat = isSelected ? BorderTokens.emphasis : idleLineWidth
        return padded(content)
            .background(resolvedFill)
            .clipShape(.rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(resolvedBorder, lineWidth: lineWidth)
            )
    }

    @ViewBuilder
    private func padded(_ content: Content) -> some View {
        if let padding {
            content.padding(padding)
        } else {
            content.padding(theme.spacing.cardPadding)
        }
    }
}

extension View {
    func selectableCardChrome(
        isSelected: Bool,
        fill: Color? = nil,
        border: Color? = nil,
        padding: EdgeInsets? = nil,
        radius: CGFloat = RadiusTokens.card,
        idleLineWidth: CGFloat = BorderTokens.hairline
    ) -> some View {
        modifier(SelectableCardChrome(
            isSelected: isSelected,
            fill: fill,
            border: border,
            padding: padding,
            radius: radius,
            idleLineWidth: idleLineWidth
        ))
    }
}

#Preview("Selectable card chrome — Light") {
    VStack(spacing: 12) {
        Text(verbatim: "Idle card").selectableCardChrome(isSelected: false)
        Text(verbatim: "Selected card").selectableCardChrome(isSelected: true)
        Text(verbatim: "Pill chip").selectableCardChrome(
            isSelected: true,
            radius: RadiusTokens.pill,
            idleLineWidth: BorderTokens.regular
        )
    }
    .padding()
    .withTheme(ThemeManager())
}

#Preview("Selectable card chrome — Dark") {
    VStack(spacing: 12) {
        Text(verbatim: "Idle card").selectableCardChrome(isSelected: false)
        Text(verbatim: "Selected card").selectableCardChrome(isSelected: true)
    }
    .padding()
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}
