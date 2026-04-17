import Foundation
import SwiftData

@MainActor
@Observable
final class HomeViewModel {
    var todaysWords: [Word] = []
    var dailySet: DailySet?
    var errorMessage: String?

    func loadTodaysWords(modelContext: ModelContext, userProgress: UserProgress) async {
        do {
            let wordService = WordService(modelContext: modelContext)
            dailySet = try wordService.generateDailySet(for: Date(), userProgress: userProgress)

            guard let set = dailySet else { return }

            todaysWords = []
            for wordId in set.wordIds {
                if let word = try wordService.fetchWord(byId: wordId) {
                    todaysWords.append(word)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isWordCompleted(_ wordId: UUID) -> Bool {
        dailySet?.isWordCompleted(wordId) ?? false
    }
}
