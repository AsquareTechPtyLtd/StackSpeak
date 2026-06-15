package com.stackspeak.data

import java.time.Instant

/** In-memory user progress — the synced, persisted learning state (mirrors the
 *  syncable subset of iOS `UserProgress` + its child records). Word-id sets hold
 *  UPPERCASE UUID strings. This is what Room persists and what maps to/from
 *  `ProgressSnapshot`. */
data class UserProgress(
    val level: Int = 1,
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
    val lastCompletedDate: Instant? = null,
    val didCompleteOnboarding: Boolean = false,
    val practicedWordIds: Set<String> = emptySet(),
    val masteredWordIds: Set<String> = emptySet(),
    val bookmarkedWordIds: Set<String> = emptySet(),
    val wordsWithTwoCorrectIds: Set<String> = emptySet(),
    val wordsCreditedForLevelIds: Set<String> = emptySet(),
    val selectedStacks: Set<String> = emptySet(),
    val shuffleSeed: String,
    val wordQueueCursor: Int = 0,
    val dailyWordGoal: Int? = null,
    val reviewStates: List<ReviewRecord> = emptyList(),
    val assessmentResults: List<AssessmentRecord> = emptyList(),
    val practicedSentences: List<PracticedSentenceRecord> = emptyList(),
    val bookProgress: List<BookProgressRecord> = emptyList(),
)

data class ReviewRecord(
    val wordId: String,
    val easinessFactor: Double,
    val interval: Int,
    val repetitions: Int,
    val dueDate: Instant,
    val lastReviewedAt: Instant?,
)

data class AssessmentRecord(
    val id: String,
    val wordId: String,
    val attemptedAt: Instant,
    val isCorrect: Boolean,
    val selectedAnswer: String,
    val correctAnswer: String,
)

data class PracticedSentenceRecord(
    val wordId: String,
    val sentence: String,
    val createdAt: Instant,
    val inputMethod: String,
)

data class BookProgressRecord(
    val bookId: String,
    val lastOpenedAt: Instant,
    val currentChapterId: String?,
    val currentCardId: String?,
    val completedCardIds: List<String>,
    val lastReadingDayString: String,
    val currentStreakDays: Int,
    val longestStreakDays: Int,
)
