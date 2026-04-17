import Foundation
import SwiftData

@MainActor
final class ProgressService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func markWordPracticed(wordId: UUID, sentence: String, inputMethod: InputMethod, userProgress: UserProgress) {
        userProgress.wordsPracticedIds.insert(wordId)

        let practicedSentence = PracticedSentence(
            wordId: wordId,
            sentence: sentence,
            createdAt: Date(),
            inputMethod: inputMethod
        )
        userProgress.practicedSentences.append(practicedSentence)

        if !userProgress.reviewStates.contains(where: { $0.wordId == wordId }) {
            let reviewState = ReviewState(wordId: wordId)
            userProgress.reviewStates.append(reviewState)
        }
    }

    func markWordMastered(_ wordId: UUID, userProgress: UserProgress) {
        userProgress.masteredWordIds.insert(wordId)
    }

    func unmarkWordMastered(_ wordId: UUID, userProgress: UserProgress) {
        userProgress.masteredWordIds.remove(wordId)
    }

    func toggleBookmark(_ wordId: UUID, userProgress: UserProgress) {
        if userProgress.bookmarkedWordIds.contains(wordId) {
            userProgress.bookmarkedWordIds.remove(wordId)
        } else {
            userProgress.bookmarkedWordIds.insert(wordId)
        }
    }

    func completeDailySet(_ dailySet: DailySet, userProgress: UserProgress) throws {
        guard dailySet.isComplete else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let lastCompleted = userProgress.lastCompletedDate.map { Calendar.current.startOfDay(for: $0) }

        if let lastCompleted = lastCompleted {
            let daysBetween = Calendar.current.dateComponents([.day], from: lastCompleted, to: today).day ?? 0

            if daysBetween == 1 {
                userProgress.currentStreak += 1
            } else if daysBetween > 1 {
                userProgress.currentStreak = 1
            }
        } else {
            userProgress.currentStreak = 1
        }

        userProgress.lastCompletedDate = today
        userProgress.longestStreak = max(userProgress.longestStreak, userProgress.currentStreak)

        try modelContext.save()
    }

    func calculateStreak(userProgress: UserProgress) -> StreakInfo {
        let today = Calendar.current.startOfDay(for: Date())
        let lastCompleted = userProgress.lastCompletedDate.map { Calendar.current.startOfDay(for: $0) }

        guard let lastCompleted = lastCompleted else {
            return StreakInfo(current: 0, longest: 0, isActive: false, lastCompletedDate: nil)
        }

        let daysBetween = Calendar.current.dateComponents([.day], from: lastCompleted, to: today).day ?? 0
        let isActive = daysBetween == 0

        return StreakInfo(
            current: userProgress.currentStreak,
            longest: userProgress.longestStreak,
            isActive: isActive,
            lastCompletedDate: userProgress.lastCompletedDate
        )
    }

    func recordAssessmentResult(
        wordId: UUID,
        isCorrect: Bool,
        selectedAnswer: String,
        correctAnswer: String,
        userProgress: UserProgress
    ) -> Bool {
        let result = AssessmentResult(
            wordId: wordId,
            attemptedAt: Date(),
            isCorrect: isCorrect,
            selectedAnswer: selectedAnswer,
            correctAnswer: correctAnswer
        )
        userProgress.assessmentResults.append(result)

        let oldLevel = userProgress.level
        checkAndAdvanceLevel(userProgress: userProgress)

        return userProgress.level > oldLevel
    }

    private func checkAndAdvanceLevel(userProgress: UserProgress) {
        if LevelDefinition.canAdvance(
            currentLevel: userProgress.level,
            wordsAssessedCorrectlyTwice: userProgress.wordsAssessedCorrectlyTwice
        ) {
            userProgress.level += 1
            userProgress.addMandatoryStacks(for: userProgress.level)
        }
    }

    func getNewStacksForLevel(_ level: Int) -> (mandatory: Set<WordStack>, optional: Set<WordStack>) {
        let mandatory = WordStack.newMandatoryStacks(for: level)
        let optional = WordStack.newOptionalStacks(for: level)
        return (mandatory, optional)
    }
}

struct StreakInfo {
    let current: Int
    let longest: Int
    let isActive: Bool
    let lastCompletedDate: Date?
}
