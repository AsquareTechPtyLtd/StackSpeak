import SwiftUI

/// SRS flashcard.
///
/// FL2 — heavy 3-D rotation flip replaced with a quick fade + slight tilt.
///   The mirror-compensation hack is gone.
/// FL3 — "Again" uses the new `bad` (red) token. Honest negative signal.
/// FL1 — "Tap to flip" hint hides after the first ever flip.
/// F2  — surface shadow replaced with a hairline.
struct FlashcardView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hasFlippedFlashcard") private var hasFlippedFlashcard = false

    let word: Word
    let onAgain: () -> Void
    let onGood: () -> Void

    @State private var isFlipped = false
    @State private var flipTrigger = 0

    var body: some View {
        VStack(spacing: theme.spacing.xl) {
            Spacer()

            cardSurface
                .frame(height: 360)
                .padding(.horizontal, theme.spacing.xl)

            if isFlipped {
                actionButtons
            } else if !hasFlippedFlashcard {
                Text("review.flashcard.tapToFlip")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkFaint)
            }

            Spacer()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: flipTrigger)
    }

    private var cardSurface: some View {
        ZStack {
            if isFlipped {
                backSide
            } else {
                frontSide
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(theme.spacing.xxl)
        .background(theme.colors.surface)
        .clipShape(.rect(cornerRadius: RadiusTokens.card))
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .stroke(theme.colors.line, lineWidth: 0.5)
        )
        .rotationEffect(.degrees(isFlipped ? 0 : -1))
        .animation(reduceMotion ? nil : MotionTokens.snappy, value: isFlipped)
        .onTapGesture {
            flipTrigger &+= 1
            withAnimation(reduceMotion ? nil : MotionTokens.standard) {
                isFlipped.toggle()
            }
            if !hasFlippedFlashcard { hasFlippedFlashcard = true }
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
        .transition(.opacity)
    }

    private var backSide: some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            Text(word.shortDefinition)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
                .fixedSize(horizontal: false, vertical: true)

            Divider().background(theme.colors.line)

            Text(word.exampleSentence)
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
                .italic()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity)
    }

    private var actionButtons: some View {
        HStack(spacing: theme.spacing.lg) {
            Button {
                onAgain()
                reset()
            } label: {
                Text("review.flashcard.again")
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.bad)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacing.lg)
                    .background(theme.colors.bad.opacity(0.10))
                    .clipShape(.rect(cornerRadius: RadiusTokens.card))
            }
            .buttonStyle(.plain)

            Button {
                onGood()
                reset()
            } label: {
                Text("review.flashcard.gotIt")
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.good)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacing.lg)
                    .background(theme.colors.good.opacity(0.10))
                    .clipShape(.rect(cornerRadius: RadiusTokens.card))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacing.xl)
    }

    private func reset() {
        withAnimation(reduceMotion ? nil : MotionTokens.standard) {
            isFlipped = false
        }
    }
}
