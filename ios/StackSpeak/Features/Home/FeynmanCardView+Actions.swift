import SwiftUI

// MARK: - Stage transitions, submit/skip/report actions, recording

extension FeynmanCardView {
    /// Stages where a left-swipe should move to the next stage. The explain
    /// stage is excluded because it owns a text editor + Submit button, and
    /// done is terminal.
    var isSwipeAdvanceStage: Bool {
        switch stage {
        case .simple, .technical, .connector: return true
        case .explain, .done: return false
        }
    }

    /// Horizontal left-swipe advances the stage. Right-swipe is intentionally
    /// not handled — that gesture belongs to the navigation back-edge.
    var swipeAdvanceGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                guard isSwipeAdvanceStage else { return }
                guard value.startLocation.x > Self.systemEdgeGutter else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy) * 1.5 else { return }
                // Track only leftward motion; apply rubber-band damping so the
                // card resists past the threshold instead of free-sliding.
                let leftward = min(dx, 0)
                dragOffset = leftward * 0.55
            }
            .onEnded { value in
                let resetAnimation: Animation? = reduceMotion ? nil : MotionTokens.snappy
                defer {
                    withAnimation(resetAnimation) { dragOffset = 0 }
                }
                guard isSwipeAdvanceStage else { return }
                guard value.startLocation.x > Self.systemEdgeGutter else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                let predictedDx = value.predictedEndTranslation.width
                let isHorizontal = abs(dx) > abs(dy) * 1.5
                let crossedThreshold = dx < -60 || predictedDx < -120
                if isHorizontal && crossedThreshold {
                    advance()
                }
            }
    }

    // MARK: - Stage transitions

    func advance() {
        guard let next = nextStage(from: stage) else { return }
        advanceTrigger &+= 1
        withAnimation(reduceMotion ? nil : MotionTokens.standard) {
            stage = next
        }
        if next == .done { onStageDidReachDone() }
    }

    /// Forward stage delegating to FeynmanStage.next so the transition table
    /// stays in one place (and is independently testable).
    func nextStage(from current: FeynmanStage) -> FeynmanStage? {
        current.next(isComingSoon: isComingSoon)
    }

    /// Inverse of nextStage. Used by the header back button.
    func previousStage(from current: FeynmanStage) -> FeynmanStage? {
        current.previous(isComingSoon: isComingSoon)
    }

    func retreat() {
        guard let prev = previousStage(from: stage) else { return }
        withAnimation(reduceMotion ? nil : MotionTokens.standard) {
            stage = prev
        }
    }

    // MARK: - Submit / skip / report

    func submitExplanation(trimmed: String) {
        stopRecordingIfNeeded()
        onSubmit(trimmed, inputMethod, false)
        advanceTrigger &+= 1
        let next: FeynmanStage = isComingSoon ? .done : .connector
        withAnimation(reduceMotion ? nil : MotionTokens.standard) {
            stage = next
        }
        if next == .done { onStageDidReachDone() }
    }

    func submitAsComingSoon() {
        stopRecordingIfNeeded()
        onSubmit("", .typed, false)
        advanceTrigger &+= 1
        withAnimation(reduceMotion ? nil : MotionTokens.standard) {
            stage = .done
        }
        onStageDidReachDone()
    }

    func skipWord() {
        stopRecordingIfNeeded()
        onSubmit("", .typed, true)  // mark as mastered
        advanceTrigger &+= 1
        withAnimation(reduceMotion ? nil : MotionTokens.standard) {
            stage = .done
        }
        onStageDidReachDone()
    }

    func reportAndSkip() {
        stopRecordingIfNeeded()
        showReport = true
    }

    /// Mutates progress (mark mastered, advance to done) only after the user
    /// successfully submits the report. Wired as the report sheet's
    /// onSubmitted callback so canceling the sheet leaves the card untouched.
    func finalizeReportSkip() {
        onSubmit("", .typed, true)
        advanceTrigger &+= 1
        withAnimation(reduceMotion ? nil : MotionTokens.standard) {
            stage = .done
        }
        onStageDidReachDone()
    }

    // MARK: - Recording

    func toggleRecording() {
        guard let speech = speechService else { return }
        if speech.isRecording {
            speech.stopRecording()
            return
        }
        Task { @MainActor in
            if speech.authorizationStatus == .notDetermined {
                _ = await speech.requestAuthorization()
            }
            guard speech.authorizationStatus == .authorized else {
                micError = String(localized: "feynman.explain.micDenied")
                return
            }
            do {
                try speech.startRecording()
                micError = nil
            } catch {
                micError = error.localizedDescription
            }
        }
    }

    func stopRecordingIfNeeded() {
        if speechService?.isRecording == true {
            speechService?.stopRecording()
        }
    }
}
