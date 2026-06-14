import Foundation
import SwiftData

@MainActor
@Observable
final class HomeViewModel {
    var dailySet: DailySet?
    var wordsById: [UUID: Word] = [:]
    var errorMessage: String?
    /// False until the first `loadTodaysWords` finishes. Lets the view tell
    /// "still loading" apart from "genuinely all mastered" — without it, the
    /// empty (computed) `todaysWords` briefly flashes the all-mastered state.
    var hasLoaded = false

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
        // Mark loaded on any non-cancelled exit (success, no-set, or error); a
        // cancelled load leaves it for the superseding load to set.
        defer { if !Task.isCancelled { hasLoaded = true } }
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
