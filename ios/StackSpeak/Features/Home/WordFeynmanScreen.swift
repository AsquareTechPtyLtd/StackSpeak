import SwiftUI

/// Single-word destination pushed from the Today list.
///
/// Wraps `FeynmanCardView`. When the card reaches the `done` stage, briefly
/// celebrates and then pops back to Today so the user can pick their next word.
struct WordFeynmanScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    let word: Word
    let userProgress: UserProgress
    let isCompleted: Bool
    let latestExplanation: PracticedSentence?
    let onSubmit: (UUID, String, InputMethod, Bool) -> Void

    @State private var didJustComplete = false
    @State private var autoAdvanceTask: Task<Void, Never>?

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
                    scheduleAutoAdvance()
                },
                onStageDidReachDone: {
                    didJustComplete = true
                    scheduleAutoAdvance()
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
        .onDisappear {
            cancelAutoAdvance()
        }
    }

    private var shouldShowCompletionCTA: Bool {
        isCompleted || didJustComplete
    }

    @ViewBuilder
    private var completionCTA: some View {
        PrimaryCTAButton("today.backToToday") {
            cancelAutoAdvance()
            dismiss()
        }
    }

    /// Auto-pop back to Today after a brief celebration moment, so the user
    /// returns to the list and chooses their next word themselves.
    private func scheduleAutoAdvance() {
        cancelAutoAdvance()

        autoAdvanceTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await MainActor.run { dismiss() }
        }
    }

    private func cancelAutoAdvance() {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
    }
}
