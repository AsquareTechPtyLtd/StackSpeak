package com.stackspeak.data.local

import com.stackspeak.data.AssessmentRecord
import com.stackspeak.data.BookProgressRecord
import com.stackspeak.data.PracticedSentenceRecord
import com.stackspeak.data.ReviewRecord
import com.stackspeak.data.UserProgress
import java.time.Instant

/**
 * Persists [UserProgress] to Room and reads it back. The entity layer is a flat
 * mirror of the domain model (dates → epoch-millis, id sets → CSV); this store is
 * the single place that conversion lives, keeping Room ↔ domain round-trips lossless.
 */
class ProgressLocalStore(
    private val progressDao: ProgressDao,
) {
    suspend fun save(progress: UserProgress) {
        progressDao.upsertProgress(progress.toEntity())

        progressDao.clearReviewStates()
        progressDao.upsertReviewStates(progress.reviewStates.map { it.toEntity() })

        progressDao.clearAssessmentResults()
        progressDao.upsertAssessmentResults(progress.assessmentResults.map { it.toEntity() })

        progressDao.clearPracticedSentences()
        progressDao.upsertPracticedSentences(progress.practicedSentences.map { it.toEntity() })

        progressDao.clearBookProgress()
        progressDao.upsertBookProgress(progress.bookProgress.map { it.toEntity() })
    }

    /** Returns persisted progress, or null if none saved yet. */
    suspend fun load(): UserProgress? {
        val e = progressDao.getProgress() ?: return null
        return UserProgress(
            level = e.level,
            currentStreak = e.currentStreak,
            longestStreak = e.longestStreak,
            lastCompletedDate = e.lastCompletedDateMillis?.let(Instant::ofEpochMilli),
            didCompleteOnboarding = e.didCompleteOnboarding,
            practicedWordIds = e.practicedWordIds.toIdSet(),
            masteredWordIds = e.masteredWordIds.toIdSet(),
            bookmarkedWordIds = e.bookmarkedWordIds.toIdSet(),
            wordsWithTwoCorrectIds = e.wordsWithTwoCorrectIds.toIdSet(),
            wordsCreditedForLevelIds = e.wordsCreditedForLevelIds.toIdSet(),
            selectedStacks = e.selectedStacks.toIdSet(),
            shuffleSeed = e.shuffleSeed,
            wordQueueCursor = e.wordQueueCursor,
            dailyWordGoal = e.dailyWordGoal,
            reviewStates = progressDao.getReviewStates().map {
                ReviewRecord(it.wordId, it.easinessFactor, it.interval, it.repetitions,
                    Instant.ofEpochMilli(it.dueDateMillis), it.lastReviewedAtMillis?.let(Instant::ofEpochMilli))
            },
            assessmentResults = progressDao.getAssessmentResults().map {
                AssessmentRecord(it.id, it.wordId, Instant.ofEpochMilli(it.attemptedAtMillis),
                    it.isCorrect, it.selectedAnswer, it.correctAnswer)
            },
            practicedSentences = progressDao.getPracticedSentences().map {
                PracticedSentenceRecord(it.wordId, it.sentence, Instant.ofEpochMilli(it.createdAtMillis), it.inputMethod)
            },
            bookProgress = progressDao.getBookProgress().map {
                BookProgressRecord(it.bookId, Instant.ofEpochMilli(it.lastOpenedAtMillis),
                    it.currentChapterId, it.currentCardId, it.completedCardIds.toIdList(),
                    it.lastReadingDayString, it.currentStreakDays, it.longestStreakDays)
            },
        )
    }

    private fun UserProgress.toEntity() = UserProgressEntity(
        level = level,
        currentStreak = currentStreak,
        longestStreak = longestStreak,
        lastCompletedDateMillis = lastCompletedDate?.toEpochMilli(),
        didCompleteOnboarding = didCompleteOnboarding,
        practicedWordIds = practicedWordIds.toCsv(),
        masteredWordIds = masteredWordIds.toCsv(),
        bookmarkedWordIds = bookmarkedWordIds.toCsv(),
        wordsWithTwoCorrectIds = wordsWithTwoCorrectIds.toCsv(),
        wordsCreditedForLevelIds = wordsCreditedForLevelIds.toCsv(),
        selectedStacks = selectedStacks.toCsv(),
        shuffleSeed = shuffleSeed,
        wordQueueCursor = wordQueueCursor,
        dailyWordGoal = dailyWordGoal,
    )

    private fun ReviewRecord.toEntity() = ReviewStateEntity(
        wordId, easinessFactor, interval, repetitions, dueDate.toEpochMilli(), lastReviewedAt?.toEpochMilli())

    private fun AssessmentRecord.toEntity() = AssessmentResultEntity(
        id, wordId, attemptedAt.toEpochMilli(), isCorrect, selectedAnswer, correctAnswer)

    private fun PracticedSentenceRecord.toEntity() = PracticedSentenceEntity(
        wordId = wordId, sentence = sentence, createdAtMillis = createdAt.toEpochMilli(), inputMethod = inputMethod)

    private fun BookProgressRecord.toEntity() = BookProgressEntity(
        bookId, lastOpenedAt.toEpochMilli(), currentChapterId, currentCardId,
        completedCardIds.joinToString(","), lastReadingDayString, currentStreakDays, longestStreakDays)
}

// CSV helpers: id sets are sorted for a stable encoding; empty string ⇒ empty.
private fun Set<String>.toCsv(): String = sorted().joinToString(",")
private fun String.toIdSet(): Set<String> = if (isEmpty()) emptySet() else split(",").toSet()
private fun String.toIdList(): List<String> = if (isEmpty()) emptyList() else split(",")
