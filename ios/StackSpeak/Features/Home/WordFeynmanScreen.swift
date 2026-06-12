import SwiftUI

/// Single-word destination pushed from the Today list.
///
/// Wraps `FeynmanCardView`. When the card reaches the `done` stage, surfaces
/// a Back-to-Today CTA so the user dismisses the screen explicitly.
struct WordFeynmanScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let word: Word
    let userProgress: UserProgress
    let isCompleted: Bool
    let latestExplanation: PracticedSentence?
    let onSubmit: (UUID, String, InputMethod, Bool) -> Void

    @State private var didJustComplete = false
    @State private var hasEntered = false

    var body: some View {
        VStack(spacing: theme.spacing.md) {
            FeynmanCardView(
                word: word,
                userProgress: userProgress,
                isCompleted: isCompleted,
                latestExplanation: latestExplanation,
                onSubmit: { explanation, method, markAsMastered in
                    onSubmit(word.id, explanation, method, markAsMastered)
                    withAnimation(reduceMotion ? nil : MotionTokens.standard) {
                        didJustComplete = true
                    }
                },
                onStageDidReachDone: {
                    withAnimation(reduceMotion ? nil : MotionTokens.standard) {
                        didJustComplete = true
                    }
                }
            )
            .padding(.horizontal, theme.spacing.lg)
            .padding(.top, theme.spacing.sm)
            // Entrance beat to match the completion CTA's exit choreography —
            // Reduce Motion renders the settled state immediately.
            .opacity(hasEntered ? 1 : 0)
            .offset(y: hasEntered ? 0 : 12)
            .onAppear {
                if reduceMotion {
                    hasEntered = true
                } else {
                    withAnimation(MotionTokens.standard) { hasEntered = true }
                }
            }

            if shouldShowCompletionCTA {
                completionCTA
                    .padding(.horizontal, theme.spacing.lg)
                    .padding(.bottom, theme.spacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(theme.colors.bg)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
    }

    private var shouldShowCompletionCTA: Bool {
        isCompleted || didJustComplete
    }

    @ViewBuilder
    private var completionCTA: some View {
        PrimaryCTAButton("today.backToToday") {
            dismiss()
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
        tags: ["api", "http"]
    )
}

#Preview("Word Feynman Screen — Light") {
    NavigationStack {
        WordFeynmanScreen(
            word: previewWord(),
            userProgress: UserProgress(),
            isCompleted: false,
            latestExplanation: nil,
            onSubmit: { _, _, _, _ in }
        )
    }
    .withTheme(ThemeManager())
}

#Preview("Word Feynman Screen — Dark") {
    NavigationStack {
        WordFeynmanScreen(
            word: previewWord(),
            userProgress: UserProgress(),
            isCompleted: false,
            latestExplanation: nil,
            onSubmit: { _, _, _, _ in }
        )
    }
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}
