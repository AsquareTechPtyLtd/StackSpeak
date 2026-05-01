import Testing
import Foundation
@testable import StackSpeak

/// Locks the tutorial state machine, persistence, idle timer, wrong-tap
/// escalation, skip flow, and dual-completion-path behavior described in
/// `ui-ux-tutorial-design-2026-05-01.md` (§1, §2, §6, §7, §8).
@Suite("TutorialViewModel")
@MainActor
struct TutorialViewModelTests {

    // MARK: - Step advancement (§1, §2)

    @Test("start sets currentStep to .s1 and persists step 0")
    func startToS1() {
        let vm = TutorialViewModel()
        var lastPersisted: Int? = -999
        var persistCalls = 0
        vm.persistStepIndex = { idx in
            lastPersisted = idx
            persistCalls += 1
        }

        vm.start()

        #expect(vm.currentStep == .s1)
        #expect(lastPersisted == 0)
        #expect(persistCalls == 1)
        #expect(vm.stepNumber == 1)
        #expect(vm.totalSteps == 2)
    }

    @Test("start is idempotent while a step is active")
    func startIdempotent() {
        let vm = TutorialViewModel()
        vm.start()
        let firstStep = vm.currentStep
        vm.start()
        #expect(vm.currentStep == firstStep)
    }

    @Test("cardDidAdvanceFromSimple hides overlay until .explain (§1: technical/connector unaided)")
    func advanceHidesUntilExplain() {
        let vm = TutorialViewModel()
        vm.start()
        #expect(vm.currentStep == .s1)

        vm.cardDidAdvanceFromSimple()
        #expect(vm.currentStep == nil, "overlay hidden during technical/connector per §1")

        vm.cardDidEnterExplainStage()
        #expect(vm.currentStep == .s2)
    }

    @Test("S2 retreats and rearms (§2)")
    func s2RetreatRearm() {
        let vm = TutorialViewModel()
        vm.start()
        vm.cardDidAdvanceFromSimple()
        vm.cardDidEnterExplainStage()
        #expect(vm.currentStep == .s2)

        vm.cardDidLeaveExplainStage()
        #expect(vm.currentStep == nil)

        vm.cardDidEnterExplainStage()
        #expect(vm.currentStep == .s2, "S2 rearms on return to .explain per §2")
    }

    @Test("cardDidAdvanceFromSimple is no-op when not on S1")
    func advanceNoOpWithoutS1() {
        let vm = TutorialViewModel()
        // Tutorial never started
        vm.cardDidAdvanceFromSimple()
        #expect(vm.currentStep == nil)
    }

    @Test("currentTargetID maps to spec anchors")
    func targetIDMapping() {
        let vm = TutorialViewModel()
        vm.start()
        #expect(vm.currentTargetID == .simpleAdvance)

        vm.cardDidAdvanceFromSimple()
        vm.cardDidEnterExplainStage()
        #expect(vm.currentTargetID == .explainComposite)
    }

    // MARK: - Resume (§7)

    @Test("start with resumeAt: 1 places at S2 with pending arm")
    func resumeAtS2() {
        let vm = TutorialViewModel()
        vm.start(resumeAt: 1)
        #expect(vm.currentStep == .s2)

        // Pending state verifiable via behavior: leaving explain hides,
        // re-entering rearms.
        vm.cardDidLeaveExplainStage()
        #expect(vm.currentStep == nil)

        vm.cardDidEnterExplainStage()
        #expect(vm.currentStep == .s2)
    }

    @Test("start with out-of-range resumeAt falls back to S1")
    func resumeOutOfRangeFallsBack() {
        let vm = TutorialViewModel()
        vm.start(resumeAt: 99)
        #expect(vm.currentStep == .s1)
    }

    // MARK: - Persistence (§7)

    @Test("cardDidReachDone fires markCompleted and clears in-flight step")
    func doneCompletes() {
        let vm = TutorialViewModel()
        var completedCalls = 0
        vm.markCompleted = { completedCalls += 1 }
        var lastPersisted: Int? = -999
        vm.persistStepIndex = { lastPersisted = $0 }

        vm.start()
        vm.cardDidReachDone()

        #expect(completedCalls == 1)
        #expect(vm.currentStep == nil)
        #expect(lastPersisted == nil, "in-flight step cleared on completion")
    }

    @Test("Both completion paths land at the same dismiss path (§2/§8)")
    func bothCompletionPaths() {
        // Submit-path: simulate S1 → advance → S2 → reach done
        let submitVM = TutorialViewModel()
        var submitCompleted = 0
        submitVM.markCompleted = { submitCompleted += 1 }
        submitVM.start()
        submitVM.cardDidAdvanceFromSimple()
        submitVM.cardDidEnterExplainStage()
        submitVM.cardDidReachDone()
        #expect(submitVM.currentStep == nil)
        #expect(submitCompleted == 1)

        // Skip-as-mastered path: directly call cardDidReachDone (the
        // existing FeynmanCardView skipWord() flow fires onStageDidReachDone).
        let skipVM = TutorialViewModel()
        var skipCompleted = 0
        skipVM.markCompleted = { skipCompleted += 1 }
        skipVM.start()
        skipVM.cardDidReachDone()
        #expect(skipVM.currentStep == nil)
        #expect(skipCompleted == 1)
    }

    // MARK: - Skip flow (§3)

    @Test("handleSkipTap presents the skip dialog")
    func skipDialogPresentation() {
        let vm = TutorialViewModel()
        vm.start()
        vm.handleSkipTap()
        #expect(vm.showSkipDialog == true)
    }

    @Test("confirmSkip fires markCompleted and dismisses (§7)")
    func confirmSkipCompletes() {
        let vm = TutorialViewModel()
        var completed = 0
        vm.markCompleted = { completed += 1 }
        var lastPersisted: Int? = -999
        vm.persistStepIndex = { lastPersisted = $0 }

        vm.start()
        vm.handleSkipTap()
        vm.confirmSkip()

        #expect(completed == 1)
        #expect(vm.showSkipDialog == false)
        #expect(vm.currentStep == nil)
        #expect(lastPersisted == nil)
    }

    @Test("cancelSkip closes dialog without completing")
    func cancelSkipPreservesState() {
        let vm = TutorialViewModel()
        var completed = 0
        vm.markCompleted = { completed += 1 }

        vm.start()
        vm.handleSkipTap()
        vm.cancelSkip()

        #expect(completed == 0)
        #expect(vm.showSkipDialog == false)
        #expect(vm.currentStep == .s1)
    }

    // MARK: - Idle timer (§6)

    @Test("idle timer fires once and bumps pulseToken")
    func idleTimerOneShot() async throws {
        let vm = TutorialViewModel()
        vm.idleHintDelay = .milliseconds(60)
        vm.start()
        let startToken = vm.pulseToken
        #expect(vm.showIdleHint == false)

        try await Task.sleep(for: .milliseconds(180))

        #expect(vm.showIdleHint == true)
        let firstFire = vm.pulseToken
        #expect(firstFire > startToken)

        // Wait another idle period — must NOT chain a second pulse (§6 binding rider 4).
        try await Task.sleep(for: .milliseconds(180))
        #expect(vm.pulseToken == firstFire, "one-shot only — no chain at 16s/24s")
    }

    @Test("idle timer cancels on advance")
    func idleTimerCancelsOnAdvance() async throws {
        let vm = TutorialViewModel()
        vm.idleHintDelay = .milliseconds(80)
        vm.start()

        try await Task.sleep(for: .milliseconds(40))
        vm.cardDidAdvanceFromSimple()
        try await Task.sleep(for: .milliseconds(120))

        #expect(vm.showIdleHint == false, "advance cancels idle timer before fire")
    }

    // MARK: - Wrong-tap (§7)

    @Test("single wrong-tap bumps pulse but does not append hint")
    func singleWrongTap() {
        let vm = TutorialViewModel()
        vm.start()
        let baseline = vm.pulseToken

        vm.handleScrimWrongTap()

        #expect(vm.pulseToken == baseline + 1)
        #expect(vm.showWrongTapHint == false)
    }

    @Test("two wrong-taps in window escalate to body hint")
    func wrongTapEscalation() {
        let vm = TutorialViewModel()
        vm.start()

        vm.handleScrimWrongTap()
        vm.handleScrimWrongTap()

        #expect(vm.showWrongTapHint == true)
    }

    @Test("wrong-tap counter resets after window expires")
    func wrongTapWindowExpiry() async throws {
        let vm = TutorialViewModel()
        vm.idleHintDelay = .seconds(60)  // suppress idle interference
        vm.wrongTapWindow = .milliseconds(50)
        vm.start()

        vm.handleScrimWrongTap()
        try await Task.sleep(for: .milliseconds(120))
        vm.handleScrimWrongTap()

        #expect(vm.showWrongTapHint == false, "second tap outside window — counter reset to fresh single")
    }

    @Test("wrong-tap is a no-op when tutorial is dismissed")
    func wrongTapInactive() {
        let vm = TutorialViewModel()
        let baseline = vm.pulseToken
        vm.handleScrimWrongTap()
        #expect(vm.pulseToken == baseline)
        #expect(vm.showWrongTapHint == false)
    }

    // MARK: - Replay (§3 Branch A)

    @Test("replay forces S1 from any state")
    func replayForcesS1() {
        let vm = TutorialViewModel()
        var lastPersisted: Int? = -999
        vm.persistStepIndex = { lastPersisted = $0 }

        vm.start()
        vm.cardDidAdvanceFromSimple()  // s2Pending = true, currentStep = nil
        vm.replay()

        #expect(vm.currentStep == .s1)
        #expect(lastPersisted == 0)
    }

    @Test("replay clears wrong-tap and idle hint state")
    func replayClearsTransientFlags() {
        let vm = TutorialViewModel()
        vm.start()
        vm.handleScrimWrongTap()
        vm.handleScrimWrongTap()
        #expect(vm.showWrongTapHint == true)

        vm.replay()
        #expect(vm.showWrongTapHint == false)
        #expect(vm.showIdleHint == false)
    }
}
