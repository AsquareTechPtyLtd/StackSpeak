import SwiftUI

struct FlashcardView: View {
    @Environment(\.theme) private var theme

    let word: Word
    let onAgain: () -> Void
    let onGood: () -> Void

    @State private var isFlipped = false

    var body: some View {
        VStack(spacing: theme.spacing.xl) {
            Spacer()

            ZStack {
                // Render both sides to avoid flicker during rotation
                frontSide
                    .opacity(isFlipped ? 0 : 1)
                    .rotation3DEffect(
                        .degrees(isFlipped ? -90 : 0),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )

                backSide
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(
                        .degrees(isFlipped ? 0 : 90),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 400)
            .padding(theme.spacing.xxxl)
            .background(theme.colors.surface)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isFlipped.toggle()
                }
            }
            .padding(.horizontal, theme.spacing.xl)

            if isFlipped {
                actionButtons
            } else {
                Text("review.flashcard.tapToFlip")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkFaint)
            }

            Spacer()
        }
    }

    private var frontSide: some View {
        VStack(spacing: theme.spacing.lg) {
            Text(word.word)
                .font(TypographyTokens.title1)
                .foregroundColor(theme.colors.ink)

            Text(word.pronunciation)
                .font(TypographyTokens.mono)
                .foregroundColor(theme.colors.inkMuted)
        }
    }

    private var backSide: some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            Text(word.shortDefinition)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)

            Divider()
                .background(theme.colors.line)

            Text(word.exampleSentence)
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
                .italic()
        }
        .scaleEffect(x: -1, y: 1) // Mirror horizontally to compensate for rotation
    }

    private var actionButtons: some View {
        HStack(spacing: theme.spacing.lg) {
            Button(action: {
                onAgain()
                reset()
            }) {
                Text("review.flashcard.again")
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.warn)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacing.lg)
                    .background(theme.colors.warn.opacity(0.1))
                    .cornerRadius(12)
            }

            Button(action: {
                onGood()
                reset()
            }) {
                Text("review.flashcard.gotIt")
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.good)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacing.lg)
                    .background(theme.colors.good.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, theme.spacing.xl)
    }

    private func reset() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isFlipped = false
        }
    }
}

// Preview requires a sample Word - would need mock data infrastructure
// #Preview("Flashcard - Light") {
//     FlashcardView(word: Word.preview, onAgain: {}, onGood: {})
//         .withTheme(ThemeManager())
// }
