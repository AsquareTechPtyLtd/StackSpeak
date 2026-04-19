import Foundation
import SwiftData

@MainActor
@Observable
final class HomeViewModel {
    // Reactive: derived from dailySet and wordsById instead of cached
    var dailySet: DailySet?
    var wordsById: [UUID: Word] = [:]
    var errorMessage: String?

    // Computed property - always reflects current state
    var todaysWords: [Word] {
        guard let set = dailySet else { return [] }
        return set.wordIds.compactMap { wordsById[$0] }
    }

    func loadTodaysWords(wordService: any WordRepository, userProgress: UserProgress) async {
        guard !Task.isCancelled else { return }
        do {
            dailySet = try wordService.generateDailySet(for: Date(), userProgress: userProgress)

            guard let set = dailySet else { return }

            // Load words into the dictionary
            var loaded: [UUID: Word] = [:]
            for wordId in set.wordIds {
                guard !Task.isCancelled else { return }
                if let word = try wordService.fetchWord(byId: wordId) {
                    loaded[wordId] = word
                }
            }
            wordsById = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isWordCompleted(_ wordId: UUID) -> Bool {
        dailySet?.isWordCompleted(wordId) ?? false
    }
}
