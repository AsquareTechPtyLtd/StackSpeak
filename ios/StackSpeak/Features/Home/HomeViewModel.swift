import Foundation
import SwiftData

@MainActor
@Observable
final class HomeViewModel {
    var dailySet: DailySet?
    var wordsById: [UUID: Word] = [:]
    var errorMessage: String?
    var currentIndex: Int = 0

    var todaysWords: [Word] {
        guard let set = dailySet else { return [] }
        return set.wordIds.compactMap { wordsById[$0] }
    }

    func isWordCompleted(_ wordId: UUID) -> Bool {
        dailySet?.isWordCompleted(wordId) ?? false
    }

    /// Used by the Today list flow: after completing a word, the screen
    /// offers a "Next word" CTA that pushes the next still-undone word in
    /// the day's order. `nil` when nothing else is left.
    func nextUndoneWord(after wordId: UUID) -> Word? {
        guard let set = dailySet,
              let currentIdx = set.wordIds.firstIndex(of: wordId) else { return nil }
        let candidates = set.wordIds[(currentIdx + 1)...] + set.wordIds[..<currentIdx]
        for id in candidates where !set.isWordCompleted(id) {
            if let word = wordsById[id] { return word }
        }
        return nil
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
    /// if the day is now fully complete, drives the streak update.
    /// `explanation` may be empty — the coming-soon path calls this without content.
    /// `markAsMastered` when true immediately adds to masteredWordIds (and only there —
    /// mastery never touches the assessment caches or grants level credit).
    func submitExplanation(
        for wordId: UUID,
        explanation: String,
        inputMethod: InputMethod,
        markAsMastered: Bool,
        services: Services,
        userProgress: UserProgress
    ) {
        guard let set = dailySet else { return }

        // Practice state, daily-set completion, and the streak update are committed
        // as one atomic save inside `recordWordCompletion`. If it throws, nothing is
        // persisted — the day cannot end up "complete" without its streak credit.
        do {
            try services.progress.recordWordCompletion(
                wordId: wordId,
                sentence: explanation,
                inputMethod: inputMethod,
                markAsMastered: markAsMastered,
                dailySet: set,
                userProgress: userProgress
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
