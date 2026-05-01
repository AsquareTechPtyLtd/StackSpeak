import SwiftUI

/// Single-word destination pushed from the Today list.
///
/// Wraps `FeynmanCardView`. When the card reaches the `done` stage, surfaces
/// a Back-to-Today CTA so the user dismisses the screen explicitly.
///
/// **Tutorial host:** for word #1 of a fresh user (`!didCompleteTutorial`),
/// renders the `TutorialOverlay` walkthrough on top of the card. Owns the
/// `@SceneStorage("tutorial.stepIndex")` for in-flight resume after
/// background → foreground (§7), and bumps `measureToken` on
/// `scenePhase == .active` so the anchor PreferenceKey re-resolves after
/// rotation / Dynamic Type changes.
struct WordFeynmanScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    let word: Word
    let userProgress: UserProgress
    let isCompleted: Bool
    /// True when this word is `DailySet.words.first` for today — i.e. the
    /// gate condition for the first-time tutorial walkthrough (combined
    /// with `!userProgress.didCompleteTutorial`).
    let isFirstWordOfDay: Bool
    let latestExplanation: PracticedSentence?
    let onSubmit: (UUID, String, InputMethod, Bool) -> Void

    @State private var didJustComplete = false
    @State private var tutorialVM = TutorialViewModel()
    @State private var measureToken = UUID()
    @State private var didWireTutorialCallbacks = false
    @SceneStorage("tutorial.stepIndex") private var tutorialStepIndex: Int = -1

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
                    // Both completion paths (submit AND skip-as-mastered)
                    // land here per §2/§8 of the council log.
                    tutorialVM.cardDidReachDone()
                },
                onStageChange: { newStage in
                    handleCardStageChange(newStage)
                },
                onShowWalkthrough: {
                    tutorialVM.replay()
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
        .overlayPreferenceValue(TutorialAnchorPreferenceKey.self) { anchors in
            GeometryReader { proxy in
                tutorialOverlayLayer(anchors: anchors, proxy: proxy)
            }
        }
        .onAppear { setupTutorialIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            // §7: re-trigger anchorPreference measurement on scene
            // re-activation; rotation or Dynamic Type may have changed
            // target rects while backgrounded.
            if phase == .active {
                measureToken = UUID()
            }
        }
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

    // MARK: - Tutorial overlay layer

    @ViewBuilder
    private func tutorialOverlayLayer(
        anchors: [TutorialTargetID: [Anchor<CGRect>]],
        proxy: GeometryProxy
    ) -> some View {
        let resolvedRect: CGRect? = {
            guard let id = tutorialVM.currentTargetID,
                  let bag = anchors[id], !bag.isEmpty else { return nil }
            // Union all anchors published under this ID — see
            // `TutorialAnchorPreferenceKey` for why arrays are used.
            let rects = bag.map { proxy[$0] }
            return rects.dropFirst().reduce(rects[0]) { $0.union($1) }
        }()

        TutorialOverlay(
            viewModel: tutorialVM,
            targetRect: resolvedRect
        )
        .id(measureToken)
    }

    /// Translates `FeynmanCardView` stage transitions into VM events. S1
    /// advance fires when leaving `.simple`; S2 arms when leaving and rearms
    /// when re-entering `.explain` (§2 retreat behavior).
    private func handleCardStageChange(_ newStage: FeynmanStage) {
        if tutorialVM.currentStep == .s1, newStage != .simple {
            tutorialVM.cardDidAdvanceFromSimple()
        }
        if newStage == .explain {
            tutorialVM.cardDidEnterExplainStage()
        } else {
            tutorialVM.cardDidLeaveExplainStage()
        }
    }

    private func setupTutorialIfNeeded() {
        // Wire persistence callbacks once. The closure captures the
        // @SceneStorage projected binding (reference-semantic) so writes
        // hit the live scene storage even though `self` is a value type.
        if !didWireTutorialCallbacks {
            let stepBinding = $tutorialStepIndex
            let progress = userProgress
            tutorialVM.persistStepIndex = { newIndex in
                stepBinding.wrappedValue = newIndex ?? -1
            }
            tutorialVM.markCompleted = {
                progress.didCompleteTutorial = true
            }
            didWireTutorialCallbacks = true
        }

        // Trigger if we're on word #1 and the user hasn't completed the
        // tutorial yet. Idempotent on re-mount thanks to `start`'s
        // currentStep nil-guard.
        guard isFirstWordOfDay,
              !userProgress.didCompleteTutorial,
              tutorialVM.currentStep == nil else { return }

        let resumeIndex = tutorialStepIndex >= 0 ? tutorialStepIndex : nil
        tutorialVM.start(resumeAt: resumeIndex)
    }
}
