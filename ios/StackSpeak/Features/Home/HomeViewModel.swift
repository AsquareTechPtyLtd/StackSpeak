import Foundation
import SwiftData

@MainActor
@Observable
final class HomeViewModel {
    var dailySet: DailySet?
    var wordsById: [UUID: Word] = [:]
    var errorMessage: String?
    var currentIndex: Int = 0
    /// Set when the user's submission of today's last card just completed the day.
    /// The view reads this to trigger the level-up check and any end-of-day UI.
    var justCompletedDay: Bool = false

    var todaysWords: [Word] {
        guard let set = dailySet else { return [] }
        return set.wordIds.compactMap { wordsById[$0] }
    }

    func isWordCompleted(_ wordId: UUID) -> Bool {
        dailySet?.isWordCompleted(wordId) ?? false
    }

    /// Most recent explanation the user recorded for this word, if any. Used by the
    /// Feynman card's Done stage to echo back what was submitted.
    func latestExplanation(for wordId: UUID, userProgress: UserProgress) -> PracticedSentence? {
        userProgress.practicedSentences
            .filter { $0.wordId == wordId }
            .max(by: { $0.createdAt < $1.createdAt })
    }

    func loadTodaysWords(wordService: any WordRepository, userProgress: UserProgress) async {
        guard !Task.isCancelled else { return }
        do {
            dailySet = try wordService.generateDailySet(for: Date(), userProgress: userProgress)

            guard let set = dailySet else { return }

            var loaded: [UUID: Word] = [:]
            for wordId in set.wordIds {
                guard !Task.isCancelled else { return }
                if let word = try wordService.fetchWord(byId: wordId) {
                    loaded[wordId] = word
                }
            }
            wordsById = loaded

            // Open the deck on the first unfinished card, so a returning user
            // lands on what they still need to do rather than a done card.
            if let firstUnfinished = set.wordIds.firstIndex(where: { !set.isWordCompleted($0) }) {
                currentIndex = firstUnfinished
            } else {
                currentIndex = max(set.wordIds.count - 1, 0)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Records a user explanation for a word, marks it complete in today's set, and
    /// if the day is now fully complete, drives the streak/level pipeline.
    /// `explanation` may be empty — the coming-soon path calls this without content.
    /// `markAsMastered` when true immediately adds to masteredWordIds and wordsWithTwoCorrectIds.
    func submitExplanation(
        for wordId: UUID,
        explanation: String,
        inputMethod: InputMethod,
        markAsMastered: Bool,
        services: Services,
        userProgress: UserProgress
    ) {
        services.progress.markWordPracticed(
            wordId: wordId,
            sentence: explanation,
            inputMethod: inputMethod,
            markAsMastered: markAsMastered,
            userProgress: userProgress
        )

        guard let set = dailySet else { return }
        set.markWordCompleted(wordId)

        if set.isComplete {
            do {
                try services.progress.completeDailySet(set, userProgress: userProgress)
                justCompletedDay = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// True when the word is unbackfilled for the Feynman flow — either simpleDefinition
    /// or connector is empty. Coming-soon cards are still completable but with a
    /// shortened flow.
    func isComingSoon(_ word: Word) -> Bool {
        word.simpleDefinition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || word.connector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
