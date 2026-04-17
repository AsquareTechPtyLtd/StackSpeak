import Foundation
import SwiftData

@MainActor
final class ReviewSchedulerService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchDueReviews(for userProgress: UserProgress) -> [ReviewState] {
        let now = Date()
        return userProgress.reviewStates
            .filter { $0.dueDate <= now }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func recordReview(reviewState: ReviewState, quality: ReviewQuality) throws {
        let qualityValue = quality.rawValue
        reviewState.updateAfterReview(quality: qualityValue)
        try modelContext.save()
    }

    func getReviewStats(for userProgress: UserProgress) -> ReviewStats {
        let now = Date()
        let dueCount = userProgress.reviewStates.filter { $0.dueDate <= now }.count
        let totalCount = userProgress.reviewStates.count

        let reviewedToday = userProgress.reviewStates.filter { state in
            guard let lastReviewed = state.lastReviewedAt else { return false }
            return Calendar.current.isDateInToday(lastReviewed)
        }.count

        return ReviewStats(
            dueCount: dueCount,
            totalCount: totalCount,
            reviewedToday: reviewedToday
        )
    }
}

enum ReviewQuality: Int {
    case again = 2
    case good = 4
}

struct ReviewStats {
    let dueCount: Int
    let totalCount: Int
    let reviewedToday: Int
}
