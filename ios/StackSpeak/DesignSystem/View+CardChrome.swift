import SwiftUI

/// Standard card chrome shared across Profile, Home, Flashcard, and Feynman card surfaces:
/// `surface` background, card-radius corners, and a hairline `line` stroke.
private struct CardChrome: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .background(theme.colors.surface)
            .clipShape(.rect(cornerRadius: RadiusTokens.card))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .stroke(theme.colors.line, lineWidth: 0.5)
            )
    }
}

extension View {
    func cardChrome() -> some View { modifier(CardChrome()) }
}
