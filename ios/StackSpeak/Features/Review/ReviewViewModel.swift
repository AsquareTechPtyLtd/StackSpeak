import Foundation
import SwiftData

@MainActor
@Observable
final class ReviewViewModel {
    var dueReviews: [ReviewState] = []
    var words: [UUID: Word] = [:]
    var currentIndex = 0

    var eligibleAssessmentWords: [Word] = []
    var currentAssessmentIndex = 0
    /// Increments each time eligible words reload, forcing SwiftUI to recreate AssessmentView instances.
    var assessmentGeneration = 0
    var assessmentLoaded = false

    func reviewedTodayCount(userProgress: UserProgress) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return userProgress.reviewStates.filter { state in
            guard let lastReviewed = state.lastReviewedAt else { return false }
            return Calendar.current.startOfDay(for: lastReviewed) >= today
        }.count
    }

    func loadDueReviews(progress: UserProgress) {
        dueReviews = progress.reviewStates
            .filter { $0.dueDate <= Date() }
            .sorted { $0.dueDate < $1.dueDate }
        currentIndex = 0
    }

    func loadWords(wordService: any WordRepository) async {
        for reviewState in dueReviews {
            guard words[reviewState.wordId] == nil else { continue }
            if let word = try? wordService.fetchWord(byId: reviewState.wordId) {
                words[reviewState.wordId] = word
            }
            guard !Task.isCancelled else { return }
        }
    }

    func loadEligibleAssessmentWords(wordService: any WordRepository, userProgress: UserProgress) async {
        let eligible = userProgress.wordsEligibleForAssessment()

        var loaded: [Word] = []
        for wordId in eligible {
            guard !Task.isCancelled else { return }
            if userProgress.canAttemptAssessment(for: wordId),
               let word = try? wordService.fetchWord(byId: wordId) {
                loaded.append(word)
            }
        }

        // Deterministic shuffle: same user state → same assessment order
        var sorted = loaded.sorted { $0.id.uuidString < $1.id.uuidString }
        var rng = SeededRandomGenerator(seed: stableHash(userProgress.shuffleSeed.uuidString + "assessment"))
        for i in stride(from: sorted.count - 1, through: 1, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            sorted.swapAt(i, j)
        }

        eligibleAssessmentWords = sorted
        currentAssessmentIndex = 0
        assessmentGeneration += 1
        assessmentLoaded = true
    }
}
