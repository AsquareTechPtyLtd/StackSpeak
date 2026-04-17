import Foundation
import SwiftData

@MainActor
@Observable
final class ReviewViewModel {
    var dueReviews: [ReviewState] = []
    var words: [UUID: Word] = [:]
    var currentIndex = 0
    var reviewedCount = 0

    var eligibleAssessmentWords: [Word] = []
    var currentAssessmentIndex = 0

    func loadDueReviews(progress: UserProgress) {
        dueReviews = progress.reviewStates
            .filter { $0.dueDate <= Date() }
            .sorted { $0.dueDate < $1.dueDate }

        currentIndex = 0
    }

    func loadWords(from modelContext: ModelContext) async {
        let wordService = WordService(modelContext: modelContext)

        for reviewState in dueReviews {
            if let word = try? wordService.fetchWord(byId: reviewState.wordId) {
                words[reviewState.wordId] = word
            }
        }
    }

    func loadEligibleAssessmentWords(modelContext: ModelContext, userProgress: UserProgress) async {
        let wordService = WordService(modelContext: modelContext)
        let eligible = userProgress.wordsEligibleForAssessment()

        var loadedWords: [Word] = []
        for wordId in eligible {
            if userProgress.canAttemptAssessment(for: wordId),
               let word = try? wordService.fetchWord(byId: wordId) {
                loadedWords.append(word)
            }
        }

        eligibleAssessmentWords = loadedWords.shuffled()
        currentAssessmentIndex = 0
    }
}
