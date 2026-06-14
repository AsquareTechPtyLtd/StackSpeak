package com.stackspeak.domain

import kotlinx.serialization.Serializable
import java.time.Instant

/**
 * Platform-neutral sync record — the cross-platform contract. Must serialize to
 * the *identical* JSON shape as iOS `ProgressSnapshot.swift` so a user's progress
 * is portable iPhone ↔ iPad ↔ Android. One JSONB blob per user.
 *
 * Parity rules (see shared/test-fixtures/README.md): camelCase keys = property
 * names; dates ISO-8601 with no fractional seconds (Z); nil optionals are omitted
 * keys, not null; word-id strings are UPPERCASE. Entitlement, daily counters, and
 * device prefs are deliberately NOT here.
 */
@Serializable
data class ProgressSnapshot(
    val schemaVersion: Int,
    @Serializable(InstantIso8601Serializer::class) val updatedAt: Instant,

    val level: Int,
    val currentStreak: Int,
    val longestStreak: Int,
    @Serializable(InstantIso8601Serializer::class) val lastCompletedDate: Instant? = null,
    val didCompleteOnboarding: Boolean,

    val practicedWordIds: List<String>,
    val masteredWordIds: List<String>,
    val bookmarkedWordIds: List<String>,
    val wordsWithTwoCorrectIds: List<String>,
    val wordsCreditedForLevelIds: List<String>,

    val selectedStacks: List<String>,
    val shuffleSeed: String,
    val wordQueueCursor: Int,

    // v2 (2026-06). Optional/defaulted so pre-v2 rows still decode; a missing
    // value means the default 5 on apply.
    val dailyWordGoal: Int? = null,

    val reviewStates: List<ReviewStateDTO>,
    val assessmentResults: List<AssessmentResultDTO>,
    val practicedSentences: List<PracticedSentenceDTO>,
    val bookProgress: List<BookProgressDTO>,
) {
    companion object {
        const val CURRENT_SCHEMA_VERSION = 2
    }

    @Serializable
    data class ReviewStateDTO(
        val wordId: String,
        val easinessFactor: Double,
        val interval: Int,
        val repetitions: Int,
        @Serializable(InstantIso8601Serializer::class) val dueDate: Instant,
        @Serializable(InstantIso8601Serializer::class) val lastReviewedAt: Instant? = null,
    )

    @Serializable
    data class AssessmentResultDTO(
        val id: String,
        val wordId: String,
        @Serializable(InstantIso8601Serializer::class) val attemptedAt: Instant,
        val isCorrect: Boolean,
        val selectedAnswer: String,
        val correctAnswer: String,
    )

    @Serializable
    data class PracticedSentenceDTO(
        val wordId: String,
        val sentence: String,
        @Serializable(InstantIso8601Serializer::class) val createdAt: Instant,
        val inputMethod: String,
    )

    @Serializable
    data class BookProgressDTO(
        val bookId: String,
        @Serializable(InstantIso8601Serializer::class) val lastOpenedAt: Instant,
        val currentChapterId: String? = null,
        val currentCardId: String? = null,
        val completedCardIds: List<String>,
        val lastReadingDayString: String,
        val currentStreakDays: Int,
        val longestStreakDays: Int,
    )
}
