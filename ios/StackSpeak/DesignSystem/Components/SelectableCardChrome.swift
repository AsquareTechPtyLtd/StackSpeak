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
    /// Defaults to the card padding (EdgeInsets); OptionButton uses the
    /// tighter uniform `md`.
    var padding: CGFloat?

    func body(content: Content) -> some View {
        let resolvedFill: Color = fill ?? (isSelected ? theme.colors.accentBg : theme.colors.surface)
        let resolvedBorder: Color = border ?? (isSelected ? theme.colors.accent : theme.colors.line)
        let lineWidth: CGFloat = isSelected ? BorderTokens.emphasis : BorderTokens.hairline
        return padded(content)
            .background(resolvedFill)
            .clipShape(.rect(cornerRadius: RadiusTokens.card))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
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
