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
    let onEasy: () -> Void

    /// One haptic channel for all card events (mirrors AssessmentView's
    /// enum-trigger pattern); the counter makes repeats of the same kind fire.
    private struct FeedbackEvent: Equatable {
        enum Kind { case flip, again, good, easy }
        var count = 0
        var kind: Kind?

        mutating func fire(_ kind: Kind) {
            count &+= 1
            self.kind = kind
        }
    }

    @State private var isFlipped = false
    @State private var feedback = FeedbackEvent()

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
        .sensoryFeedback(trigger: feedback) { _, new in
            switch new.kind {
            case .flip, .again: return .impact(weight: .light)
            case .good, .easy: return .success
            case nil: return nil
            }
        }
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
        feedback.fire(.flip)
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

    /// Again (lapse) → Got it (clean recall) → Easy (effortless), worst-to-best
    /// left-to-right. Easy is the only grade that raises the SM-2 easiness
    /// factor, letting a well-known card stretch out faster.
    private var actionButtons: some View {
        HStack(spacing: theme.spacing.md) {
            gradeButton(titleKey: "review.flashcard.again", hintKey: "a11y.flashcard.again.hint",
                        color: theme.colors.bad, kind: .again, action: onAgain)
            gradeButton(titleKey: "review.flashcard.gotIt", hintKey: "a11y.flashcard.gotIt.hint",
                        color: theme.colors.good, kind: .good, action: onGood)
            gradeButton(titleKey: "review.flashcard.easy", hintKey: "a11y.flashcard.easy.hint",
                        color: theme.colors.accent, kind: .easy, action: onEasy)
        }
        .padding(.horizontal, theme.spacing.xl)
    }

    private func gradeButton(titleKey: LocalizedStringKey, hintKey: LocalizedStringKey,
                             color: Color, kind: FeedbackEvent.Kind,
                             action: @escaping () -> Void) -> some View {
        Button {
            feedback.fire(kind)
            action()
            reset()
        } label: {
            Text(titleKey)
                .font(TypographyTokens.headline)
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.lg)
                .background(color.opacity(0.10))
                .clipShape(.rect(cornerRadius: RadiusTokens.card))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(hintKey))
    }

    private func reset() {
        withAnimation(reduceMotion ? nil : MotionTokens.standard) {
            isFlipped = false
        }
        // The flip-back and button collapse are silent to VoiceOver — say
        // what happened and that a new card is up (SC 4.1.3).
        VoiceOverAnnouncer.post(String(localized: "a11y.flashcard.answerRecorded"))
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
        onGood: {},
        onEasy: {}
    )
    .withTheme(ThemeManager())
}

#Preview("Flashcard — Dark") {
    FlashcardView(
        word: previewWord(),
        onAgain: {},
        onGood: {},
        onEasy: {}
    )
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}
