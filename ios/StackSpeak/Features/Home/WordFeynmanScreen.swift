import SwiftUI

/// Single-word destination pushed from the Today list.
///
/// Wraps `FeynmanCardView` and provides the post-completion affordance:
/// when the card lands on the `done` stage and there's another undone word
/// in the day, surfaces a "Next word" button that pops back to Today and
/// pushes the next word. If everything's done, the button reads "Back to
/// Today" and just pops.
struct WordFeynmanScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    let word: Word
    let userProgress: UserProgress
    let isCompleted: Bool
    let latestExplanation: PracticedSentence?
    let nextUndoneWord: Word?
    let onSubmit: (UUID, String, InputMethod, Bool) -> Void
    let onAdvanceToNext: (UUID) -> Void

    @State private var didJustComplete = false

    var body: some View {
        VStack(spacing: theme.spacing.md) {
            FeynmanCardView(
                word: word,
                userProgress: userProgress,
                isCompleted: isCompleted,
                latestExplanation: latestExplanation,
                onSubmit: { explanation, method, markAsMastered in
                    onSubmit(word.id, explanation, method, markAsMastered)
                    didJustComplete = true
                },
                onStageDidReachDone: {
                    didJustComplete = true
                }
            )
            .padding(.horizontal, theme.spacing.lg)
            .padding(.top, theme.spacing.sm)

            // Post-completion CTA — appears once the card is on the done
            // stage (either freshly completed or revisited).
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
        if let next = nextUndoneWord {
            PrimaryCTAButton("today.nextWord") {
                onAdvanceToNext(next.id)
            }
        } else {
            PrimaryCTAButton("today.backToToday") {
                dismiss()
            }
        }
    }
}
