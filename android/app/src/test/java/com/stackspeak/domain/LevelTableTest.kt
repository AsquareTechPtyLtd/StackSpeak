package com.stackspeak.domain

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * M1e parity: the 60-level table must match levels.json exactly, and the
 * credit-threshold progression rules must behave like iOS `Level.swift`.
 */
class LevelTableTest {

    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun tableMatchesIosFixture() {
        val fromFixture = json.decodeFromString(
            kotlinx.serialization.builtins.ListSerializer(LevelDefinition.serializer()),
            Fixtures.read("levels.json"),
        )
        assertEquals("60 levels", 60, fromFixture.size)
        assertEquals("level table identical to iOS", fromFixture, Levels.all)
        assertEquals("maxLevel", 60, Levels.maxLevel)
    }

    @Test
    fun canAdvanceFollowsThresholds() {
        // L1 → L2 needs 4 points.
        assertFalse(Levels.canAdvance(currentLevel = 1, points = 3))
        assertTrue(Levels.canAdvance(currentLevel = 1, points = 4))
        // Enough points can cross several levels' thresholds at once (caller may skip).
        assertTrue(Levels.canAdvance(currentLevel = 1, points = 20))
        // No level beyond the cap.
        assertFalse(Levels.canAdvance(currentLevel = 60, points = 100_000))
        assertNull(Levels.nextLevel(after = 60))
    }

    @Test
    fun progressToNextLevelIsFractional() {
        // At L1 (threshold 0) with 2 of the 4 points needed for L2.
        val p = Levels.progressToNextLevel(currentLevel = 1, points = 2)!!
        assertEquals(0.5, p.progress, 1e-9)
        assertEquals(2, p.pointsRemaining)
        assertEquals(2, p.nextLevel.level)
        assertNull(Levels.progressToNextLevel(currentLevel = 60, points = 99))
    }
}
