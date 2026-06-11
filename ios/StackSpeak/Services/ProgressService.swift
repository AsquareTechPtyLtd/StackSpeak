import Foundation
import SwiftData

@MainActor
final class ProgressService: ProgressRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func markWordPracticed(wordId: UUID, sentence: String, inputMethod: InputMethod, markAsMastered: Bool, userProgress: UserProgress) throws {
        applyWordPracticed(wordId: wordId, sentence: sentence, inputMethod: inputMethod, markAsMastered: markAsMastered, userProgress: userProgress)
        try modelContext.save()
    }

    /// In-memory mutations for practicing a word. Does NOT save — callers that
    /// bundle this with other writes (see `recordWordCompletion`) save once at
    /// the end so the whole operation is atomic.
    private func applyWordPracticed(wordId: UUID, sentence: String, inputMethod: InputMethod, markAsMastered: Bool, userProgress: UserProgress) {
        var practiced = userProgress.wordsPracticedIds
        practiced.insert(wordId)
        userProgress.wordsPracticedIds = practiced

        // Only record a practiced sentence when there's actual content. The coming-soon
        // Feynman fallback calls this with an empty string to count the day without
        // writing a junk row into the user's explanation history.
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let practicedSentence = PracticedSentence(
                wordId: wordId,
                sentence: trimmed,
                createdAt: Date(),
                inputMethod: inputMethod
            )
            userProgress.practicedSentences.append(practicedSentence)
        }

        if !userProgress.reviewStates.contains(where: { $0.wordId == wordId }) {
            userProgress.reviewStates.append(ReviewState(wordId: wordId))
        }

        // Skip/report marks the word mastered so it won't reappear. It does NOT
        // grant level credit — progression comes only from assessment (see
        // recordAssessmentResult). Mastering excludes a word; it isn't a shortcut.
        if markAsMastered {
            var mastered = userProgress.masteredWordIds
            mastered.insert(wordId)
            userProgress.masteredWordIds = mastered
        }
    }

    /// Atomically records a completed word for the day: practice state, the
    /// daily-set completion flag, and — when this finishes the day — the streak
    /// update, all committed in a single `save()`. This prevents the day from
    /// being persisted as "complete" while streak credit is silently lost if a
    /// later step fails. Returns `true` when this completion finished the day.
    @discardableResult
    func recordWordCompletion(
        wordId: UUID,
        sentence: String,
        inputMethod: InputMethod,
        markAsMastered: Bool,
        dailySet: DailySet,
        userProgress: UserProgress
    ) throws -> Bool {
        applyWordPracticed(wordId: wordId, sentence: sentence, inputMethod: inputMethod, markAsMastered: markAsMastered, userProgress: userProgress)

        // Streak credit fires only on the transition to complete — a Pro batch
        // word completed after the base 5 are done must not re-run completion.
        let wasComplete = dailySet.isComplete
        dailySet.markWordCompleted(wordId)
        let justCompleted = dailySet.isComplete && !wasComplete
        if justCompleted {
            applyDailySetCompletion(dailySet, userProgress: userProgress)
        }

        try modelContext.save()
        return justCompleted
    }

    func markWordMastered(_ wordId: UUID, userProgress: UserProgress) throws {
        var mastered = userProgress.masteredWordIds
        mastered.insert(wordId)
        userProgress.masteredWordIds = mastered

        try modelContext.save()
    }

    func unmarkWordMastered(_ wordId: UUID, userProgress: UserProgress) throws {
        var mastered = userProgress.masteredWordIds
        mastered.remove(wordId)
        userProgress.masteredWordIds = mastered

        try modelContext.save()
    }

    func toggleBookmark(_ wordId: UUID, userProgress: UserProgress) throws {
        var bookmarked = userProgress.bookmarkedWordIds
        if bookmarked.contains(wordId) {
            bookmarked.remove(wordId)
        } else {
            bookmarked.insert(wordId)
        }
        userProgress.bookmarkedWordIds = bookmarked

        try modelContext.save()
    }

    func completeDailySet(_ dailySet: DailySet, userProgress: UserProgress) throws {
        guard dailySet.isComplete else { return }
        applyDailySetCompletion(dailySet, userProgress: userProgress)
        try modelContext.save()
    }

    /// In-memory streak update for a completed day. Does NOT save and does NOT
    /// re-check `isComplete` — callers guarantee the set is complete before
    /// calling. Kept separate so `recordWordCompletion` can bundle it into a
    /// single atomic save.
    private func applyDailySetCompletion(_ dailySet: DailySet, userProgress: UserProgress) {
        // Use user's current timezone calendar for all date calculations
        // to properly handle DST transitions and timezone changes
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        if let lastCompleted = userProgress.lastCompletedDate {
            // Normalize both dates to start of day in current timezone
            let lastDay = calendar.startOfDay(for: lastCompleted)

            // Calculate day difference using calendar arithmetic (handles DST)
            let components = calendar.dateComponents([.day], from: lastDay, to: today)
            let daysBetween = components.day ?? 0

            if daysBetween == 1 {
                // Consecutive day - increment streak
                userProgress.currentStreak += 1
            } else if daysBetween > 1 {
                // Gap in practice - reset streak
                userProgress.currentStreak = 1
            }
            // daysBetween == 0: same-day completion, no streak change
            // daysBetween < 0: shouldn't happen (time travel), treat as same-day
        } else {
            // First ever completion
            userProgress.currentStreak = 1
        }

        userProgress.lastCompletedDate = now
        userProgress.longestStreak = max(userProgress.longestStreak, userProgress.currentStreak)
    }

    /// Records an assessment result and updates the denormalized two-correct cache.
    /// Returns the new level number if the user leveled up, or nil otherwise.
    func recordAssessmentResult(
        wordId: UUID,
        isCorrect: Bool,
        selectedAnswer: String,
        correctAnswer: String,
        userProgress: UserProgress
    ) throws -> Int? {
        let result = AssessmentResult(
            wordId: wordId,
            attemptedAt: Date(),
            isCorrect: isCorrect,
            selectedAnswer: selectedAnswer,
            correctAnswer: correctAnswer
        )
        userProgress.assessmentResults.append(result)

        // Incrementally update the caches instead of rescanning all results —
        // assessmentResults grows unboundedly and this runs on the main actor.
        // Each correct answer is worth one assessment point, max two per word:
        //   1st correct → wordsCreditedForLevelIds (point 1)
        //   2nd correct → wordsWithTwoCorrectIds (point 2; canAttemptAssessment
        //     guarantees it lands on a later day)
        // The cached sets already encode the correct count: not yet tracked
        // means this is the first correct; already tracked means it's at
        // least the second.
        if isCorrect {
            var credited = userProgress.wordsCreditedForLevelIds
            if credited.insert(wordId).inserted {
                userProgress.wordsCreditedForLevelIds = credited
            } else {
                var twoCorrect = userProgress.wordsWithTwoCorrectIds
                twoCorrect.insert(wordId)
                userProgress.wordsWithTwoCorrectIds = twoCorrect
            }
        }

        let oldLevel = userProgress.level
        checkAndAdvanceLevel(userProgress: userProgress)

        try modelContext.save()

        return userProgress.level > oldLevel ? userProgress.level : nil
    }

    func getNewStacksForLevel(_ level: Int) -> (mandatory: Set<WordStack>, optional: Set<WordStack>) {
        (WordStack.newMandatoryStacks(for: level), WordStack.newOptionalStacks(for: level))
    }

    private func checkAndAdvanceLevel(userProgress: UserProgress) {
        while LevelDefinition.canAdvance(
            currentLevel: userProgress.level,
            points: userProgress.assessmentPointsForLevel
        ) {
            userProgress.level += 1
            userProgress.addMandatoryStacks(for: userProgress.level)
        }
    }
}
