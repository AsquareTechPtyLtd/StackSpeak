import SwiftUI

/// Tutorial step state machine, idle/wrong-tap behavior, and persistence
/// surface for the first-time-user walkthrough on `WordFeynmanScreen`.
///
/// See `ui-ux-tutorial-design-2026-05-01.md` for the council-arbitrated
/// spec. Sub-decisions implemented here:
/// - §1 — two teaching spotlights (S1 simple, S2 explain composite).
/// - §2 — mirror-real-control advance + S2 retreat/rearm on `.explain`.
/// - §3 — skip dialog state.
/// - §6 — single-shot 8s idle re-cue (no chaining at 16s/24s).
/// - §7 — pass-through wrong-tap counting (2 in 8s → append nudge);
///        persistence via host-provided callbacks.
///
/// **Persistence is host-driven.** `@SceneStorage` is a View-scoped
/// property wrapper and cannot live on an `@Observable` model — the host
/// (`WordFeynmanScreen`, Task #6) owns `@SceneStorage("tutorial.stepIndex")`
/// and bridges via the `persistStepIndex` closure. `markCompleted` flips
/// `UserProgress.didCompleteTutorial` (Task #5).
@MainActor
@Observable
final class TutorialViewModel {
    /// Two teaching spotlights per §1. `nil` = tutorial dismissed.
    enum Step: Int, CaseIterable {
        case s1 = 0
        case s2 = 1
    }

    // MARK: - Public state (read by TutorialOverlay)

    var currentStep: Step?
    var showSkipDialog: Bool = false
    var showIdleHint: Bool = false
    var showWrongTapHint: Bool = false

    /// Monotonic counter — bump triggers a single-shot 240ms snappy
    /// border-opacity pulse per §6. Used by both wrong-tap and 8s-idle paths.
    var pulseToken: Int = 0

    var stepNumber: Int { (currentStep?.rawValue ?? 0) + 1 }
    var totalSteps: Int { Step.allCases.count }

    var currentTargetID: TutorialTargetID? {
        switch currentStep {
        case .s1: return .simpleAdvance
        case .s2: return .explainComposite
        case nil: return nil
        }
    }

    // MARK: - Host-provided persistence

    /// Persists the in-flight step index. Wraps the host's
    /// `@SceneStorage("tutorial.stepIndex")`. `nil` = clear in-flight state
    /// (tutorial dismissed cleanly).
    var persistStepIndex: ((Int?) -> Void)?

    /// Sets `UserProgress.didCompleteTutorial = true`. Called on natural
    /// completion (`cardDidReachDone`) AND confirmed skip (§7).
    var markCompleted: (() -> Void)?

    // MARK: - Tunable timing (override in tests)

    /// 8s per §6/§7. Exposed for unit tests to short-circuit the wait.
    var idleHintDelay: Duration = .seconds(8)
    /// 8s wrong-tap pairing window per §7. Exposed for unit tests.
    var wrongTapWindow: Duration = .seconds(8)

    // MARK: - Internal state

    private var idleTask: Task<Void, Never>?
    private var wrongTapWindowTask: Task<Void, Never>?
    private var wrongTapCount: Int = 0
    /// True between S1-advance and the next time the card sits on
    /// `.explain`. Per §1 ("no spotlight" on technical/connector) and §2
    /// (S2 hides while `stage != .explain`; rearms on return). The overlay
    /// is hidden (`currentStep == nil`) while pending, then re-armed to
    /// `.s2` on `cardDidEnterExplainStage`.
    private var s2Pending: Bool = false

    // MARK: - Lifecycle

    /// Begin the walkthrough. Called by host on first arrival at
    /// `WordFeynmanScreen` for word #1 when `!didCompleteTutorial`.
    ///
    /// `resumeAt` accepts a previously-persisted step index (from
    /// `@SceneStorage`) so a backgrounded session resumes mid-flight per §7.
    /// Pass `nil` (or out-of-range value) to start from S1.
    func start(resumeAt resumeIndex: Int? = nil) {
        guard currentStep == nil, !s2Pending else { return }
        let step = resumeIndex.flatMap(Step.init(rawValue:)) ?? .s1
        // Resuming at S2 means the user advanced past simple in a prior
        // session. Mark S2 as pending; the host's first
        // `handleCardStageChange` will either rearm (if stage == explain)
        // or settle into the hidden-pending state.
        if step == .s2 {
            s2Pending = true
            currentStep = .s2
        } else {
            currentStep = step
        }
        persistStepIndex?(step.rawValue)
        resetTransientFlags()
        scheduleIdleHint()
    }

    /// Re-fire the walkthrough from S1 regardless of completion flag.
    /// Invoked from the ⋯ "Show walkthrough" menu item (Task #8).
    func replay() {
        cancelTimers()
        s2Pending = false
        currentStep = .s1
        persistStepIndex?(Step.s1.rawValue)
        resetTransientFlags()
        scheduleIdleHint()
    }

    /// Dismiss the overlay without marking complete. Caller is responsible
    /// for calling `markCompleted?()` first if completion semantics apply.
    func dismiss() {
        cancelTimers()
        currentStep = nil
        showSkipDialog = false
        s2Pending = false
        resetTransientFlags()
        persistStepIndex?(nil)
    }

    private func resetTransientFlags() {
        showIdleHint = false
        showWrongTapHint = false
        wrongTapCount = 0
    }

    // MARK: - Card-driven events

    /// Called by host when the underlying card advances past `.simple`.
    /// Per §1, the technical and connector stages are unaided ("no
    /// spotlight"), so we hide the overlay (`currentStep = nil`) and arm
    /// S2 — which rearms on `cardDidEnterExplainStage`.
    func cardDidAdvanceFromSimple() {
        guard currentStep == .s1 else { return }
        s2Pending = true
        currentStep = nil
        persistStepIndex?(Step.s2.rawValue)
        cancelTimers()
        showIdleHint = false
        showWrongTapHint = false
        wrongTapCount = 0
    }

    /// Called by host on `onStageDidReachDone` — both submit AND
    /// skip-as-mastered paths land here (§2, §8). Marks complete and dismisses.
    func cardDidReachDone() {
        markCompleted?()
        dismiss()
    }

    /// Called by host's stage observation when the card arrives at
    /// `.explain` — either via natural forward progression after S1, or
    /// on retreat-then-return. Rearms S2 if pending.
    func cardDidEnterExplainStage() {
        guard s2Pending, currentStep != .s2 else { return }
        currentStep = .s2
        showIdleHint = false
        showWrongTapHint = false
        wrongTapCount = 0
        scheduleIdleHint()
    }

    /// Per §2: "S2 spotlight hides while `stage != .explain`; rearms on
    /// return." Sets s2Pending so re-entry rearms.
    func cardDidLeaveExplainStage() {
        guard currentStep == .s2 else { return }
        s2Pending = true
        currentStep = nil
        cancelTimers()
        showIdleHint = false
        showWrongTapHint = false
    }

    // MARK: - User-driven events

    /// Hit-test fallback from the scrim's even-odd contentShape (§7) —
    /// taps in the dimmed gutter outside spotlight, leading 32pt strip,
    /// and instruction-card exclusion. Fires border pulse, resets idle
    /// timer per §6, and counts toward the 2-in-8s wrong-tap escalation.
    func handleScrimWrongTap() {
        guard currentStep != nil else { return }
        pulseToken &+= 1
        // §6: wrong-tap pulse preempts the idle pulse and resets the 8s timer.
        scheduleIdleHint()

        wrongTapCount += 1
        if wrongTapCount >= 2 {
            showWrongTapHint = true
            wrongTapCount = 0
            wrongTapWindowTask?.cancel()
            wrongTapWindowTask = nil
            return
        }
        startWrongTapWindow()
    }

    func handleSkipTap() {
        showSkipDialog = true
    }

    func confirmSkip() {
        showSkipDialog = false
        // §7: persistence flag set on Skip-confirmation — same as completion.
        markCompleted?()
        dismiss()
    }

    func cancelSkip() {
        showSkipDialog = false
    }

    // MARK: - Timer plumbing

    /// Schedules a single-shot fire `idleHintDelay` from now. §6 binding
    /// rider 4: one-shot only — no chained pulses at 16s/24s.
    /// Cancels any in-flight idle task first; subsequent interactions
    /// (advance, wrong-tap) reschedule.
    private func scheduleIdleHint() {
        idleTask?.cancel()
        let delay = idleHintDelay
        idleTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self, self.currentStep != nil else { return }
            let wasAlreadyShowing = self.showIdleHint
            self.showIdleHint = true
            if !wasAlreadyShowing {
                // §6 one-shot pulse + §6 binding rider 2: idle hint posts
                // a polite VoiceOver `.announce` when it appears (UIKit
                // bridge handled in `TutorialOverlay`).
                self.pulseToken &+= 1
            }
        }
    }

    private func startWrongTapWindow() {
        wrongTapWindowTask?.cancel()
        let window = wrongTapWindow
        wrongTapWindowTask = Task { [weak self] in
            try? await Task.sleep(for: window)
            guard !Task.isCancelled, let self else { return }
            self.wrongTapCount = 0
        }
    }

    private func cancelTimers() {
        idleTask?.cancel()
        idleTask = nil
        wrongTapWindowTask?.cancel()
        wrongTapWindowTask = nil
    }
}
