package com.stackspeak.domain

import com.stackspeak.data.AssessmentRecord
import com.stackspeak.data.PracticedSentenceRecord
import com.stackspeak.data.UserProgress
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/**
 * Pure progression rules — ported from iOS `UserProgress` + `ProgressService`.
 * Each returns a new [UserProgress] (no mutation), so the offline loop is
 * deterministic and unit-testable. Calendar-day math uses the supplied zone.
 */
object Progression {

    const val WRONG_ANSWER_RETRY_COOLDOWN_SECONDS = 15L * 60

    /** Level currency: 1 point for a word's first correct, +1 for a second (later-day) correct. */
    fun assessmentPoints(p: UserProgress): Int =
        p.wordsCreditedForLevelIds.size + p.wordsWithTwoCorrectIds.size

    /** Records a practiced word + its explanation sentence (idempotent on the id set). */
    fun recordPractice(p: UserProgress, wordId: String, sentence: String, inputMethod: String, now: Instant): UserProgress =
        p.copy(
            practicedWordIds = p.practicedWordIds + wordId,
            practicedSentences = p.practicedSentences + PracticedSentenceRecord(wordId, sentence, now, inputMethod),
        )

    /**
     * Records an assessment attempt and advances the level if enough points accrued.
     * First correct → credited-for-level; a later correct → two-correct (each worth a
     * point). Levels never decrease and may jump several thresholds at once.
     */
    fun recordAssessment(
        p: UserProgress,
        wordId: String,
        isCorrect: Boolean,
        selectedAnswer: String,
        correctAnswer: String,
        now: Instant,
    ): UserProgress {
        val withResult = p.copy(
            assessmentResults = p.assessmentResults +
                AssessmentRecord(deterministicUUID("$wordId|${now.toEpochMilli()}"), wordId, now, isCorrect, selectedAnswer, correctAnswer),
        )
        if (!isCorrect) return withResult

        val credited = withResult.wordsCreditedForLevelIds
        val updated = when {
            wordId !in credited -> withResult.copy(wordsCreditedForLevelIds = credited + wordId)
            wordId !in withResult.wordsWithTwoCorrectIds ->
                withResult.copy(wordsWithTwoCorrectIds = withResult.wordsWithTwoCorrectIds + wordId)
            else -> withResult
        }
        return advanceLevels(updated)
    }

    /** Advances level while the accrued points clear the next threshold (never decreases). */
    fun advanceLevels(p: UserProgress): UserProgress {
        var level = p.level
        val points = assessmentPoints(p)
        while (Levels.canAdvance(level, points)) level++
        return if (level == p.level) p else p.copy(level = level)
    }

    /**
     * Whether a word can be assessed now: a wrong answer needs the cooldown elapsed;
     * a correct answer can only be re-earned on a later calendar day. Words eligible
     * at all = practiced and not yet two-correct.
     */
    fun canAttemptAssessment(p: UserProgress, wordId: String, now: Instant, zone: ZoneId): Boolean {
        if (wordId !in p.practicedWordIds || wordId in p.wordsWithTwoCorrectIds) return false
        val last = p.assessmentResults.filter { it.wordId == wordId }.maxByOrNull { it.attemptedAt } ?: return true
        return if (last.isCorrect) {
            last.attemptedAt.atZone(zone).toLocalDate() != now.atZone(zone).toLocalDate()
        } else {
            ChronoUnit.SECONDS.between(last.attemptedAt, now) >= WRONG_ANSWER_RETRY_COOLDOWN_SECONDS
        }
    }

    /** Streak shown to the user — zero if not extended today or yesterday. */
    fun displayedStreak(p: UserProgress, now: Instant, zone: ZoneId): Int {
        val last = p.lastCompletedDate ?: return 0
        val days = ChronoUnit.DAYS.between(last.atZone(zone).toLocalDate(), now.atZone(zone).toLocalDate())
        return if (days > 1) 0 else p.currentStreak
    }

    /**
     * Registers that today's set was completed: bumps the streak (continued if
     * yesterday, reset to 1 if there was a gap, unchanged if already counted today),
     * updates the longest-streak high-water mark, and stamps the completion date.
     */
    fun registerDailyCompletion(p: UserProgress, now: Instant, zone: ZoneId): UserProgress {
        val today = now.atZone(zone).toLocalDate()
        val lastDay = p.lastCompletedDate?.atZone(zone)?.toLocalDate()
        if (lastDay == today) return p // already counted today
        val newStreak = when {
            lastDay == null -> 1
            ChronoUnit.DAYS.between(lastDay, today) == 1L -> p.currentStreak + 1
            else -> 1
        }
        return p.copy(
            currentStreak = newStreak,
            longestStreak = maxOf(p.longestStreak, newStreak),
            lastCompletedDate = now,
        )
    }
}
