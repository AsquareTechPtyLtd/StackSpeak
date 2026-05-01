import Testing
import Foundation
@testable import StackSpeak

@Suite("ReviewViewModel Tests")
@MainActor
struct ReviewViewModelTests {

    @Test("reviewedTodayCount returns count of reviews from today")
    func testReviewedTodayCount() async throws {
        let viewModel = ReviewViewModel()
        let userProgress = UserProgress()

        // No reviews - should return 0
        #expect(viewModel.reviewedTodayCount(userProgress: userProgress) == 0)

        // Add review from today
        let todayReview = ReviewState(wordId: UUID())
        todayReview.lastReviewedAt = Date()
        userProgress.reviewStates.append(todayReview)

        #expect(viewModel.reviewedTodayCount(userProgress: userProgress) == 1)

        // Add review from yesterday - should not count
        let yesterdayReview = ReviewState(wordId: UUID())
        yesterdayReview.lastReviewedAt = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        userProgress.reviewStates.append(yesterdayReview)

        #expect(viewModel.reviewedTodayCount(userProgress: userProgress) == 1)

        // Add another review from today
        let anotherTodayReview = ReviewState(wordId: UUID())
        anotherTodayReview.lastReviewedAt = Date()
        userProgress.reviewStates.append(anotherTodayReview)

        #expect(viewModel.reviewedTodayCount(userProgress: userProgress) == 2)
    }

    @Test("loadDueReviews filters and sorts by due date")
    func testLoadDueReviews() async throws {
        let viewModel = ReviewViewModel()
        let userProgress = UserProgress()

        let now = Date()
        let past = Calendar.current.date(byAdding: .hour, value: -1, to: now)!
        let future = Calendar.current.date(byAdding: .day, value: 1, to: now)!

        // Add reviews with different due dates
        let dueReview1 = ReviewState(wordId: UUID())
        dueReview1.dueDate = past
        userProgress.reviewStates.append(dueReview1)

        let futureReview = ReviewState(wordId: UUID())
        futureReview.dueDate = future
        userProgress.reviewStates.append(futureReview)

        let dueReview2 = ReviewState(wordId: UUID())
        dueReview2.dueDate = Date()
        userProgress.reviewStates.append(dueReview2)

        viewModel.loadDueReviews(progress: userProgress)

        // Should only include due reviews (past and now, not future)
        #expect(viewModel.dueReviews.count == 2)

        // Should be sorted by due date (earliest first)
        #expect(viewModel.dueReviews.first?.dueDate == past)
    }

    @Test("currentIndex resets when loading new reviews")
    func testCurrentIndexReset() async throws {
        let viewModel = ReviewViewModel()
        let userProgress = UserProgress()

        viewModel.currentIndex = 5
        viewModel.loadDueReviews(progress: userProgress)

        #expect(viewModel.currentIndex == 0)
    }
}
