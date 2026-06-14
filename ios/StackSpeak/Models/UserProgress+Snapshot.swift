import Foundation

// Maps the local SwiftData progress onto the platform-neutral `ProgressSnapshot`
// that syncs. Read-only here; applying a remote snapshot back into SwiftData
// (create/update rows + conflict resolution) lives in the sync layer, which has
// a ModelContext.
extension UserProgress {
    /// Builds the syncable snapshot. Book progress is stored as separate rows,
    /// so the caller passes the fetched `BookProgress` records in.
    func makeSnapshot(bookProgress: [BookProgress], now: Date = Date()) -> ProgressSnapshot {
        ProgressSnapshot(
            schemaVersion: ProgressSnapshot.currentSchemaVersion,
            updatedAt: now,
            level: level,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastCompletedDate: lastCompletedDate,
            didCompleteOnboarding: didCompleteOnboarding,
            practicedWordIds: Self.ids(wordsPracticedIds),
            masteredWordIds: Self.ids(masteredWordIds),
            bookmarkedWordIds: Self.ids(bookmarkedWordIds),
            wordsWithTwoCorrectIds: Self.ids(wordsWithTwoCorrectIds),
            wordsCreditedForLevelIds: Self.ids(wordsCreditedForLevelIds),
            selectedStacks: selectedStacks.sorted(),
            shuffleSeed: shuffleSeed.uuidString,
            wordQueueCursor: wordQueueCursor,
            dailyWordGoal: dailyWordGoal,
            reviewStates: reviewStates.map {
                .init(wordId: $0.wordId.uuidString, easinessFactor: $0.easinessFactor,
                      interval: $0.interval, repetitions: $0.repetitions,
                      dueDate: $0.dueDate, lastReviewedAt: $0.lastReviewedAt)
            },
            assessmentResults: assessmentResults.map {
                .init(id: $0.id.uuidString, wordId: $0.wordId.uuidString,
                      attemptedAt: $0.attemptedAt, isCorrect: $0.isCorrect,
                      selectedAnswer: $0.selectedAnswer, correctAnswer: $0.correctAnswer)
            },
            practicedSentences: practicedSentences.map {
                .init(wordId: $0.wordId.uuidString, sentence: $0.sentence,
                      createdAt: $0.createdAt, inputMethod: $0.inputMethod.rawValue)
            },
            bookProgress: bookProgress.map {
                .init(bookId: $0.bookId, lastOpenedAt: $0.lastOpenedAt,
                      currentChapterId: $0.currentChapterId, currentCardId: $0.currentCardId,
                      completedCardIds: $0.completedCardIds.sorted(),
                      lastReadingDayString: $0.lastReadingDayString,
                      currentStreakDays: $0.currentStreakDays,
                      longestStreakDays: $0.longestStreakDays)
            }
        )
    }

    /// Sorted string forms of a UUID set — stable ordering keeps the serialized
    /// JSON deterministic (cleaner diffs, stable equality checks during sync).
    private static func ids(_ set: Set<UUID>) -> [String] {
        set.map(\.uuidString).sorted()
    }
}
