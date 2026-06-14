package com.stackspeak.domain

import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlin.math.roundToInt

/** A card's SM-2 scheduling state (the synced subset of iOS `ReviewState`). */
data class Sm2State(
    val easinessFactor: Double,
    val interval: Int,
    val repetitions: Int,
    val dueDate: Instant,
    val lastReviewedAt: Instant?,
)

/**
 * SM-2 spaced repetition, ported from iOS `ReviewState.swift`. Must match the
 * `sm2.json` golden vectors so a synced card resurfaces on the same day per
 * device. Two subtleties carried over exactly:
 *  - EF updates on **every** review (incl. lapses), but the interval multiplies
 *    by the EF captured **before** that update (`oldEf`).
 *  - The due date is jittered (not the stored interval) by a stable multiplier
 *    derived from the wordId's raw UUID bytes via FNV-1a.
 *
 * Due dates use whole-day (UTC) addition, matching the fixtures' UTC calendar.
 * Local-timezone calendar-day semantics (DST) are a higher layer's concern.
 */
object Sm2 {
    const val INITIAL_EASINESS = 2.5
    const val MIN_EASINESS = 1.3
    const val EASINESS_INCREMENT = 0.1
    const val EASINESS_QUALITY_COEFF = 0.08
    const val EASINESS_QUALITY_SQUARED_COEFF = 0.02
    const val QUALITY_FAIL_THRESHOLD = 3
    const val FIRST_INTERVAL = 1
    const val SECOND_INTERVAL = 6
    const val INTERVAL_FUZZ = 0.1

    /** A fresh card: due tomorrow, no jitter (matches iOS `ReviewState.init`). */
    fun initial(now: Instant): Sm2State =
        Sm2State(INITIAL_EASINESS, FIRST_INTERVAL, 0, now.plus(1, ChronoUnit.DAYS), null)

    fun updateAfterReview(state: Sm2State, wordId: String, quality: Int, now: Instant): Sm2State {
        val qDelta = (5 - quality).toDouble()
        val efAdjustment =
            EASINESS_INCREMENT - qDelta * (EASINESS_QUALITY_COEFF + qDelta * EASINESS_QUALITY_SQUARED_COEFF)
        val oldEf = state.easinessFactor
        val newEf = maxOf(MIN_EASINESS, oldEf + efAdjustment)

        var interval = state.interval
        var repetitions = state.repetitions
        if (quality < QUALITY_FAIL_THRESHOLD) {
            repetitions = 0
            interval = FIRST_INTERVAL
        } else {
            interval = when (repetitions) {
                0 -> FIRST_INTERVAL
                1 -> SECOND_INTERVAL
                else -> (interval * oldEf).toInt() // truncates toward zero, like Swift Int(_:)
            }
            repetitions += 1
        }

        val offset = maxOf(1, (interval * intervalJitter(wordId)).roundToInt())
        return Sm2State(
            easinessFactor = newEf,
            interval = interval,
            repetitions = repetitions,
            dueDate = now.plus(offset.toLong(), ChronoUnit.DAYS),
            lastReviewedAt = now,
        )
    }

    /** Stable multiplier in [0.9, 1.1] from the wordId's raw UUID bytes (FNV-1a). */
    private fun intervalJitter(wordId: String): Double {
        var hash = 14695981039346656037UL
        for (b in uuidBytes(wordId)) {
            hash = (hash xor b.toUByte().toULong()) * 1099511628211UL
        }
        val fraction = (hash % 1000UL).toDouble() / 999.0
        return (1 - INTERVAL_FUZZ) + fraction * (INTERVAL_FUZZ * 2)
    }
}
