package com.stackspeak.domain

import com.stackspeak.data.UserProgress
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.ZoneId

/** M3: offline progression rules — credit/leveling, streak, assessment eligibility. */
class ProgressionTest {

    private val zone = ZoneId.of("UTC")
    private val w = "0326034C-C2B5-4C98-36E2-AF1800358A56"
    private fun base() = UserProgress(shuffleSeed = "ABCDEF01-2345-6789-ABCD-EF0123456789", selectedStacks = setOf("api-basic"))

    @Test
    fun firstCorrectCreditsOnce_secondCreditsTwoCorrect_thirdNoChange() {
        val t0 = Instant.parse("2026-01-01T00:00:00Z")
        var p = base()
        p = Progression.recordAssessment(p, w, true, "x", "x", t0)
        assertEquals(setOf(w), p.wordsCreditedForLevelIds)
        assertEquals(emptySet<String>(), p.wordsWithTwoCorrectIds)
        assertEquals(1, Progression.assessmentPoints(p))

        p = Progression.recordAssessment(p, w, true, "x", "x", t0.plusSeconds(86_400))
        assertEquals(setOf(w), p.wordsWithTwoCorrectIds)
        assertEquals(2, Progression.assessmentPoints(p))

        p = Progression.recordAssessment(p, w, true, "x", "x", t0.plusSeconds(2 * 86_400))
        assertEquals(2, Progression.assessmentPoints(p)) // capped at 2 per word
    }

    @Test
    fun levelAdvancesAtThresholdAndNeverDecreases() {
        var p = base()
        // L1→L2 needs 4 points. Credit 4 distinct words once each (4 points).
        listOf("a", "b", "c", "d").forEachIndexed { i, k ->
            p = Progression.recordAssessment(p, "$k-id", true, "x", "x", Instant.ofEpochSecond(i.toLong()))
        }
        assertEquals(4, Progression.assessmentPoints(p))
        assertTrue("advanced past L1", p.level >= 2)
        // A subsequent wrong answer never lowers the level.
        val before = p.level
        p = Progression.recordAssessment(p, "e-id", false, "x", "y", Instant.ofEpochSecond(99))
        assertEquals(before, p.level)
    }

    @Test
    fun streakContinuesResetsAndDeduplicates() {
        val day1 = Instant.parse("2026-01-01T12:00:00Z")
        var p = Progression.registerDailyCompletion(base(), day1, zone)
        assertEquals(1, p.currentStreak)

        // same day again → unchanged
        p = Progression.registerDailyCompletion(p, day1.plusSeconds(3600), zone)
        assertEquals(1, p.currentStreak)

        // next day → 2
        p = Progression.registerDailyCompletion(p, day1.plusSeconds(86_400), zone)
        assertEquals(2, p.currentStreak)
        assertEquals(2, p.longestStreak)

        // gap of 2 days → reset to 1, longest preserved
        p = Progression.registerDailyCompletion(p, day1.plusSeconds(4 * 86_400), zone)
        assertEquals(1, p.currentStreak)
        assertEquals(2, p.longestStreak)
    }

    @Test
    fun assessmentEligibilityRespectsPracticeAndCooldown() {
        val t0 = Instant.parse("2026-01-01T00:00:00Z")
        var p = base()
        // not practiced → not eligible
        assertFalse(Progression.canAttemptAssessment(p, w, t0, zone))
        p = Progression.recordPractice(p, w, "my explanation", "text", t0)
        assertTrue(Progression.canAttemptAssessment(p, w, t0, zone))
        // wrong answer → blocked until cooldown, then allowed
        p = Progression.recordAssessment(p, w, false, "x", "y", t0)
        assertFalse(Progression.canAttemptAssessment(p, w, t0.plusSeconds(60), zone))
        assertTrue(Progression.canAttemptAssessment(p, w, t0.plusSeconds(16 * 60), zone))
    }
}
