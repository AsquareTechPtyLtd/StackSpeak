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
