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
