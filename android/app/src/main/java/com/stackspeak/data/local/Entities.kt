package com.stackspeak.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Room persistence for user progress. Bundled content (words/books) is NOT
 * stored here — it loads from assets. Dates are epoch-millis Longs; id sets are
 * CSV (mirrors iOS's CSV-in-SwiftData approach). The single UserProgress row uses
 * a fixed key so there's exactly one.
 */
@Entity(tableName = "user_progress")
data class UserProgressEntity(
    @PrimaryKey val id: Int = SINGLETON_ID,
    val level: Int,
    val currentStreak: Int,
    val longestStreak: Int,
    val lastCompletedDateMillis: Long?,
    val didCompleteOnboarding: Boolean,
    val practicedWordIds: String,
    val masteredWordIds: String,
    val bookmarkedWordIds: String,
    val wordsWithTwoCorrectIds: String,
    val wordsCreditedForLevelIds: String,
    val selectedStacks: String,
    val shuffleSeed: String,
    val wordQueueCursor: Int,
    val dailyWordGoal: Int?,
) {
    companion object {
        const val SINGLETON_ID = 0
    }
}

@Entity(tableName = "review_state")
data class ReviewStateEntity(
    @PrimaryKey val wordId: String,
    val easinessFactor: Double,
    val interval: Int,
    val repetitions: Int,
    val dueDateMillis: Long,
    val lastReviewedAtMillis: Long?,
)

@Entity(tableName = "assessment_result")
data class AssessmentResultEntity(
    @PrimaryKey val id: String,
    val wordId: String,
    val attemptedAtMillis: Long,
    val isCorrect: Boolean,
    val selectedAnswer: String,
    val correctAnswer: String,
)

@Entity(tableName = "practiced_sentence")
data class PracticedSentenceEntity(
    @PrimaryKey(autoGenerate = true) val rowId: Long = 0,
    val wordId: String,
    val sentence: String,
    val createdAtMillis: Long,
    val inputMethod: String,
)

@Entity(tableName = "book_progress")
data class BookProgressEntity(
    @PrimaryKey val bookId: String,
    val lastOpenedAtMillis: Long,
    val currentChapterId: String?,
    val currentCardId: String?,
    val completedCardIds: String,
    val lastReadingDayString: String,
    val currentStreakDays: Int,
    val longestStreakDays: Int,
)

/** Today's word set — per-day, NOT synced (regenerates locally; "0/N after restore" expected). */
@Entity(tableName = "daily_set")
data class DailySetEntity(
    @PrimaryKey val dayString: String,
    val wordIds: String,
    val completedWordIds: String,
)
