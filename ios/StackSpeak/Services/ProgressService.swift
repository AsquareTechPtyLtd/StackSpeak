import Foundation
import SwiftData
import OSLog

@MainActor
final class ProgressService: ProgressRepository {
    private let modelContext: ModelContext
    private let logger = Logger(category: "ProgressService")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func markWordPracticed(wordId: UUID, sentence: String, inputMethod: InputMethod, markAsMastered: Bool, userProgress: UserProgress) {
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

        // When skip or report buttons are used, immediately mark as mastered and count
        // toward level progression so the word won't appear in future assessments.
        if markAsMastered {
            var mastered = userProgress.masteredWordIds
            mastered.insert(wordId)
            userProgress.masteredWordIds = mastered

            var twoCorrect = userProgress.wordsWithTwoCorrectIds
            twoCorrect.insert(wordId)
            userProgress.wordsWithTwoCorrectIds = twoCorrect
        }

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save word practiced: \(error.localizedDescription, privacy: .public)")
        }
    }

    func markWordMastered(_ wordId: UUID, userProgress: UserProgress) {
        var mastered = userProgress.masteredWordIds
        mastered.insert(wordId)
        userProgress.masteredWordIds = mastered

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save word mastered: \(error.localizedDescription, privacy: .public)")
        }
    }

    func unmarkWordMastered(_ wordId: UUID, userProgress: UserProgress) {
        var mastered = userProgress.masteredWordIds
        mastered.remove(wordId)
        userProgress.masteredWordIds = mastered

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save word unmastered: \(error.localizedDescription, privacy: .public)")
        }
    }

    func toggleBookmark(_ wordId: UUID, userProgress: UserProgress) {
        var bookmarked = userProgress.bookmarkedWordIds
        if bookmarked.contains(wordId) {
            bookmarked.remove(wordId)
        } else {
            bookmarked.insert(wordId)
        }
        userProgress.bookmarkedWordIds = bookmarked

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save bookmark toggle: \(error.localizedDescription, privacy: .public)")
        }
    }

    func completeDailySet(_ dailySet: DailySet, userProgress: UserProgress) throws {
        guard dailySet.isComplete else { return }

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

        try modelContext.save()
    }

    /// Records an assessment result and updates the denormalized two-correct cache.
    /// Returns the new level number if the user leveled up, or nil otherwise.
    func recordAssessmentResult(
        wordId: UUID,
        isCorrect: Bool,
        selectedAnswer: String,
        correctAnswer: String,
        userProgress: UserProgress
    ) -> Int? {
        let result = AssessmentResult(
            wordId: wordId,
            attemptedAt: Date(),
            isCorrect: isCorrect,
            selectedAnswer: selectedAnswer,
            correctAnswer: correctAnswer
        )
        userProgress.assessmentResults.append(result)

        // Incrementally update the two-correct cache instead of rescanning all results.
        if isCorrect {
            let correctCount = userProgress.assessmentResults
                .filter { $0.wordId == wordId && $0.isCorrect }.count
            if correctCount >= 2 {
                var updated = userProgress.wordsWithTwoCorrectIds
                updated.insert(wordId)
                userProgress.wordsWithTwoCorrectIds = updated
            }
        }

        let oldLevel = userProgress.level
        checkAndAdvanceLevel(userProgress: userProgress)

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save assessment result: \(error.localizedDescription, privacy: .public)")
        }

        return userProgress.level > oldLevel ? userProgress.level : nil
    }

    func getNewStacksForLevel(_ level: Int) -> (mandatory: Set<WordStack>, optional: Set<WordStack>) {
        (WordStack.newMandatoryStacks(for: level), WordStack.newOptionalStacks(for: level))
    }

    private func checkAndAdvanceLevel(userProgress: UserProgress) {
        while LevelDefinition.canAdvance(
            currentLevel: userProgress.level,
            wordsAssessedCorrectlyTwice: userProgress.wordsAssessedCorrectlyTwice
        ) {
            userProgress.level += 1
            userProgress.addMandatoryStacks(for: userProgress.level)
        }
    }
}

// StreakInfo removed - calculateStreak was unused; displayedCurrentStreak on UserProgress is the live source
