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

/// Flashcard answer quality. `rawValue` maps directly onto the SM-2 quality
/// scale (0–5) consumed by `ReviewState.updateAfterReview(quality:)`, which
/// supports the full range — new cases (e.g. `hard = 3`, `easy = 5`) can be
/// added here without touching the scheduling math.
enum ReviewQuality: Int {
    case again = 2
    case good = 4
}
