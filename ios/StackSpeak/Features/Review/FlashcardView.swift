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

    /// Deliberate fixed design height for the card surface; content is short
    /// (term + definition + example) and a stable frame keeps the flip calm.
    /// minHeight gives long definitions at large Dynamic Type room to grow.
    private static let cardIdealHeight: CGFloat = 360

    var body: some View {
        VStack(spacing: theme.spacing.xl) {
            Spacer()

            cardSurface
                .frame(minHeight: Self.cardIdealHeight)
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
        .cardChrome()
        .rotationEffect(.degrees(isFlipped ? 0 : -1))
        .animation(reduceMotion ? nil : MotionTokens.snappy, value: isFlipped)
        .onTapGesture { flip() }
        // Tap gestures are invisible to VoiceOver — expose the flip as a named
        // action and describe the card's current side.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isFlipped
            ? Text(verbatim: "\(word.shortDefinition). \(word.exampleSentence)")
            : Text(verbatim: "\(word.word). \(word.pronunciation)"))
        .accessibilityHint(Text("a11y.flashcard.flip.hint"))
        .accessibilityAction(named: Text("a11y.flashcard.flip")) { flip() }
    }

    private func flip() {
        flipTrigger &+= 1
        withAnimation(reduceMotion ? nil : MotionTokens.standard) {
            isFlipped.toggle()
        }
        if !hasFlippedFlashcard { hasFlippedFlashcard = true }
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

            // .overlay, not .background — background paints behind the
            // divider's frame and leaves the line itself system gray.
            Divider().overlay(theme.colors.line)

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
            .accessibilityHint(Text("a11y.flashcard.again.hint"))

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
            .accessibilityHint(Text("a11y.flashcard.gotIt.hint"))
        }
        .padding(.horizontal, theme.spacing.xl)
    }

    private func reset() {
        withAnimation(reduceMotion ? nil : MotionTokens.standard) {
            isFlipped = false
        }
    }
}

// MARK: - Previews

private func previewWord() -> Word {
    Word(
        id: UUID(),
        word: "idempotent",
        pronunciation: "/ˌaɪ.dəmˈpoʊ.tənt/",
        partOfSpeech: "adjective",
        shortDefinition: "Producing the same result no matter how many times it's applied.",
        simpleDefinition: "Doing it once or a hundred times gives the same outcome.",
        longDefinition: "An operation is idempotent if applying it multiple times has the same effect as applying it once.",
        techContext: "REST APIs mark GET, PUT, and DELETE as idempotent; POST is generally not.",
        exampleSentence: "A DELETE request is idempotent — deleting a resource twice is the same as deleting it once.",
        etymology: "From Latin idem (same) + potent (powerful).",
        connector: "Think of a light switch that only turns off — pressing it again changes nothing.",
        codeExampleLanguage: "swift",
        codeExampleCode: "func setActive(_ active: Bool) { isActive = active }",
        stack: "basic-web",
        unlockLevel: 1,
        tags: []
    )
}

#Preview("Flashcard — Light") {
    FlashcardView(
        word: previewWord(),
        onAgain: {},
        onGood: {}
    )
    .withTheme(ThemeManager())
}

#Preview("Flashcard — Dark") {
    FlashcardView(
        word: previewWord(),
        onAgain: {},
        onGood: {}
    )
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}
