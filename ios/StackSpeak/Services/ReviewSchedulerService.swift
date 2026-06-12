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
/// scale (0–5) consumed by `ReviewState.updateAfterReview(quality:)`.
///
/// `again` (2) is a lapse — it resets the interval and docks the easiness
/// factor. `good` (4) is a clean recall and leaves the easiness factor flat.
/// `easy` (5) is an effortless recall and *raises* the easiness factor, the
/// only grade that lets a card speed back up — without it the factor could
/// only ever decay. `hard = 3` could be added the same way if needed.
enum ReviewQuality: Int {
    case again = 2
    case good = 4
    case easy = 5
}
