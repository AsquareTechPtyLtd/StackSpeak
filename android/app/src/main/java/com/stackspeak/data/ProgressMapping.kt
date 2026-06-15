package com.stackspeak.data

import com.stackspeak.domain.ProgressSnapshot
import java.time.Instant

/**
 * Maps local [UserProgress] to/from the platform-neutral [ProgressSnapshot] —
 * ports iOS `UserProgress.makeSnapshot` (and its inverse). Id sets and
 * completed-card lists are sorted on the way out so the serialized JSON is
 * deterministic, matching iOS. The Room↔UserProgress hop is trivial field
 * copying (see local/), so UserProgress↔snapshot is the lossless contract that
 * matters.
 */
fun UserProgress.toSnapshot(now: Instant): ProgressSnapshot = ProgressSnapshot(
    schemaVersion = ProgressSnapshot.CURRENT_SCHEMA_VERSION,
    updatedAt = now,
    level = level,
    currentStreak = currentStreak,
    longestStreak = longestStreak,
    lastCompletedDate = lastCompletedDate,
    didCompleteOnboarding = didCompleteOnboarding,
    practicedWordIds = practicedWordIds.sorted(),
    masteredWordIds = masteredWordIds.sorted(),
    bookmarkedWordIds = bookmarkedWordIds.sorted(),
    wordsWithTwoCorrectIds = wordsWithTwoCorrectIds.sorted(),
    wordsCreditedForLevelIds = wordsCreditedForLevelIds.sorted(),
    selectedStacks = selectedStacks.sorted(),
    shuffleSeed = shuffleSeed,
    wordQueueCursor = wordQueueCursor,
    dailyWordGoal = dailyWordGoal,
    reviewStates = reviewStates.map {
        ProgressSnapshot.ReviewStateDTO(it.wordId, it.easinessFactor, it.interval, it.repetitions, it.dueDate, it.lastReviewedAt)
    },
    assessmentResults = assessmentResults.map {
        ProgressSnapshot.AssessmentResultDTO(it.id, it.wordId, it.attemptedAt, it.isCorrect, it.selectedAnswer, it.correctAnswer)
    },
    practicedSentences = practicedSentences.map {
        ProgressSnapshot.PracticedSentenceDTO(it.wordId, it.sentence, it.createdAt, it.inputMethod)
    },
    bookProgress = bookProgress.map {
        ProgressSnapshot.BookProgressDTO(
            it.bookId, it.lastOpenedAt, it.currentChapterId, it.currentCardId,
            it.completedCardIds.sorted(), it.lastReadingDayString, it.currentStreakDays, it.longestStreakDays,
        )
    },
)

/** Reconstructs [UserProgress] from a snapshot. A null `dailyWordGoal` (pre-v2)
 *  is preserved as null; the daily-set layer treats null as the default 5. */
fun ProgressSnapshot.toUserProgress(): UserProgress = UserProgress(
    level = level,
    currentStreak = currentStreak,
    longestStreak = longestStreak,
    lastCompletedDate = lastCompletedDate,
    didCompleteOnboarding = didCompleteOnboarding,
    practicedWordIds = practicedWordIds.toSet(),
    masteredWordIds = masteredWordIds.toSet(),
    bookmarkedWordIds = bookmarkedWordIds.toSet(),
    wordsWithTwoCorrectIds = wordsWithTwoCorrectIds.toSet(),
    wordsCreditedForLevelIds = wordsCreditedForLevelIds.toSet(),
    selectedStacks = selectedStacks.toSet(),
    shuffleSeed = shuffleSeed,
    wordQueueCursor = wordQueueCursor,
    dailyWordGoal = dailyWordGoal,
    reviewStates = reviewStates.map {
        ReviewRecord(it.wordId, it.easinessFactor, it.interval, it.repetitions, it.dueDate, it.lastReviewedAt)
    },
    assessmentResults = assessmentResults.map {
        AssessmentRecord(it.id, it.wordId, it.attemptedAt, it.isCorrect, it.selectedAnswer, it.correctAnswer)
    },
    practicedSentences = practicedSentences.map {
        PracticedSentenceRecord(it.wordId, it.sentence, it.createdAt, it.inputMethod)
    },
    bookProgress = bookProgress.map {
        BookProgressRecord(
            it.bookId, it.lastOpenedAt, it.currentChapterId, it.currentCardId,
            it.completedCardIds, it.lastReadingDayString, it.currentStreakDays, it.longestStreakDays,
        )
    },
)
