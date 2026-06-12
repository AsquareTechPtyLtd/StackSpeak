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
    /// Defaults to the card padding; OptionButton uses the tighter `md`.
    var padding: CGFloat?

    func body(content: Content) -> some View {
        content
            .padding(padding ?? theme.spacing.cardPadding)
            .background(fill ?? (isSelected ? theme.colors.accentBg : theme.colors.surface))
            .clipShape(.rect(cornerRadius: RadiusTokens.card))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .stroke(border ?? (isSelected ? theme.colors.accent : theme.colors.line),
                            lineWidth: isSelected ? BorderTokens.emphasis : BorderTokens.hairline)
            )
    }
}

extension View {
    func selectableCardChrome(
        isSelected: Bool,
        fill: Color? = nil,
        border: Color? = nil,
        padding: CGFloat? = nil
    ) -> some View {
        modifier(SelectableCardChrome(
            isSelected: isSelected,
            fill: fill,
            border: border,
            padding: padding
        ))
    }
}
