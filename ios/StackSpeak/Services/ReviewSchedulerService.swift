import Foundation
import SwiftData
import OSLog

@MainActor
final class ReviewSchedulerService: ReviewRepository {
    private let modelContext: ModelContext
    private let logger = Logger(category: "ReviewSchedulerService")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func recordReview(reviewState: ReviewState, quality: ReviewQuality) throws {
        let qualityValue = quality.rawValue
        reviewState.updateAfterReview(quality: qualityValue)
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save review: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}

enum ReviewQuality: Int {
    case again = 2
    case good = 4
}
