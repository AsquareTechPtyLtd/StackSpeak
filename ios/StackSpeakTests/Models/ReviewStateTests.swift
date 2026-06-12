import Testing
import Foundation
@testable import StackSpeak

@Suite("ReviewState — SM-2 algorithm")
struct ReviewStateTests {

    @Test("Again (quality 2) resets repetitions and sets interval to 1")
    func againResetsState() {
        let state = ReviewState(wordId: UUID())
        state.repetitions = 3
        state.interval = 10
        state.updateAfterReview(quality: 2)
        #expect(state.repetitions == 0)
        #expect(state.interval == 1)
    }

    @Test("Good (quality 4) on first rep sets interval to 1")
    func goodOnFirstRep() {
        let state = ReviewState(wordId: UUID())
        state.repetitions = 0
        state.updateAfterReview(quality: 4)
        #expect(state.repetitions == 1)
        #expect(state.interval == 1)
    }

    @Test("Good (quality 4) on second rep sets interval to 6")
    func goodOnSecondRep() {
        let state = ReviewState(wordId: UUID())
        state.repetitions = 1
        state.updateAfterReview(quality: 4)
        #expect(state.repetitions == 2)
        #expect(state.interval == 6)
    }

    @Test("Easiness factor does not drop below 1.3")
    func easinessFactorMinimum() {
        let state = ReviewState(wordId: UUID())
        state.easinessFactor = 1.4
        // quality 3 produces a slight decrease
        for _ in 0..<20 {
            state.updateAfterReview(quality: 3)
        }
        #expect(state.easinessFactor >= 1.3)
    }

    @Test("Again (quality 2) docks the easiness factor")
    func againLowersEasiness() {
        let state = ReviewState(wordId: UUID())
        #expect(state.easinessFactor == 2.5)
        state.updateAfterReview(quality: 2)
        // SM-2 q=2 adjustment: 0.1 - 3*(0.08 + 3*0.02) = -0.32
        #expect(abs(state.easinessFactor - 2.18) < 1e-9)
    }

    @Test("Good (quality 4) leaves the easiness factor unchanged")
    func goodKeepsEasinessFlat() {
        let state = ReviewState(wordId: UUID())
        state.updateAfterReview(quality: 4)
        // SM-2 q=4 adjustment is exactly 0 — which is why the EF update must
        // run on every review, not only on success, or EF would never move.
        #expect(abs(state.easinessFactor - 2.5) < 1e-9)
    }

    @Test("Repeated lapses drive the easiness factor to the 1.3 floor")
    func repeatedLapsesReachFloor() {
        let state = ReviewState(wordId: UUID())
        for _ in 0..<10 { state.updateAfterReview(quality: 2) }
        #expect(state.easinessFactor == 1.3)
    }

    // MARK: - Interval jitter

    private func dueOffsetDays(_ state: ReviewState, from now: Date) -> Int {
        Calendar.current.dateComponents([.day], from: now, to: state.dueDate).day ?? 0
    }

    @Test("Due-date jitter stays within ±10% of the interval")
    func jitterIsBounded() {
        let now = Date(timeIntervalSince1970: 0)
        let state = ReviewState(wordId: UUID())
        state.repetitions = 5
        state.interval = 10
        state.easinessFactor = 2.0
        state.updateAfterReview(quality: 4, now: now)
        // interval = 10 * 2.0 = 20; offset jittered into [18, 22]
        #expect(state.interval == 20)
        let offset = dueOffsetDays(state, from: now)
        #expect(offset >= 18 && offset <= 22)
    }

    @Test("Jitter is deterministic for a given wordId")
    func jitterIsDeterministic() {
        let now = Date(timeIntervalSince1970: 0)
        let id = UUID()
        func offset() -> Int {
            let s = ReviewState(wordId: id)
            s.repetitions = 5; s.interval = 10; s.easinessFactor = 2.0
            s.updateAfterReview(quality: 4, now: now)
            return dueOffsetDays(s, from: now)
        }
        #expect(offset() == offset())
    }

    @Test("Different words do not all land on the same day")
    func jitterDeclustersCards() {
        let now = Date(timeIntervalSince1970: 0)
        var offsets = Set<Int>()
        for _ in 0..<50 {
            let s = ReviewState(wordId: UUID())
            s.repetitions = 5; s.interval = 10; s.easinessFactor = 2.0
            s.updateAfterReview(quality: 4, now: now)
            offsets.insert(dueOffsetDays(s, from: now))
        }
        #expect(offsets.count > 1)
    }

    @Test("Due date is set to future after review")
    func dueDateIsFuture() {
        let state = ReviewState(wordId: UUID())
        let before = Date()
        state.updateAfterReview(quality: 4)
        #expect(state.dueDate > before)
    }

    @Test("lastReviewedAt is updated on review")
    func lastReviewedAtIsSet() {
        let state = ReviewState(wordId: UUID())
        #expect(state.lastReviewedAt == nil)
        state.updateAfterReview(quality: 4)
        #expect(state.lastReviewedAt != nil)
    }
}
