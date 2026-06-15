package com.stackspeak.data

import com.stackspeak.domain.ProgressSnapshot
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant

/** M2: UserProgress ↔ ProgressSnapshot mapping is lossless for synced fields. */
class ProgressMappingTest {

    private fun sample() = UserProgress(
        level = 8,
        currentStreak = 5,
        longestStreak = 12,
        lastCompletedDate = Instant.parse("2026-01-30T00:00:00Z"),
        didCompleteOnboarding = true,
        practicedWordIds = setOf("0326034C-C2B5-4C98-36E2-AF1800358A56", "D25E9FEB-D525-F60B-7F32-A769C12862F7"),
        masteredWordIds = setOf("0326034C-C2B5-4C98-36E2-AF1800358A56"),
        bookmarkedWordIds = setOf("D25E9FEB-D525-F60B-7F32-A769C12862F7"),
        wordsWithTwoCorrectIds = setOf("0326034C-C2B5-4C98-36E2-AF1800358A56"),
        wordsCreditedForLevelIds = setOf("0326034C-C2B5-4C98-36E2-AF1800358A56", "D25E9FEB-D525-F60B-7F32-A769C12862F7"),
        selectedStacks = setOf("api-basic", "gcp-basic"),
        shuffleSeed = "ABCDEF01-2345-6789-ABCD-EF0123456789",
        wordQueueCursor = 17,
        dailyWordGoal = 8,
        reviewStates = listOf(
            ReviewRecord("0326034C-C2B5-4C98-36E2-AF1800358A56", 2.6, 6, 2,
                Instant.parse("2026-02-06T00:00:00Z"), Instant.parse("2026-01-30T00:00:00Z")),
        ),
        assessmentResults = listOf(
            AssessmentRecord("59C495A5-A5B4-6613-4655-FCCFCFFDA6B1", "0326034C-C2B5-4C98-36E2-AF1800358A56",
                Instant.parse("2026-01-29T00:00:00Z"), true, "a stored copy", "a stored copy"),
        ),
        practicedSentences = listOf(
            PracticedSentenceRecord("0326034C-C2B5-4C98-36E2-AF1800358A56", "We cache responses at the edge.",
                Instant.parse("2026-01-29T00:00:00Z"), "text"),
        ),
        bookProgress = listOf(
            BookProgressRecord("designing-apis", Instant.parse("2026-01-28T00:00:00Z"), "api-ch03", "api-ch03-c002",
                listOf("api-ch03-c001", "api-ch03-c002"), "2026-01-28", 3, 7),
        ),
    )

    @Test
    fun roundTripIsLossless() {
        val original = sample()
        val now = Instant.parse("2026-01-31T00:00:00Z")
        val back = original.toSnapshot(now).toUserProgress()
        assertEquals(original, back)
    }

    @Test
    fun snapshotCarriesSchemaAndTimestamp() {
        val snap = sample().toSnapshot(Instant.parse("2026-01-31T00:00:00Z"))
        assertEquals(ProgressSnapshot.CURRENT_SCHEMA_VERSION, snap.schemaVersion)
        assertEquals(Instant.parse("2026-01-31T00:00:00Z"), snap.updatedAt)
        // id sets are sorted on the way out (deterministic JSON)
        assertEquals(snap.wordsCreditedForLevelIds, snap.wordsCreditedForLevelIds.sorted())
    }

    @Test
    fun preV2NullGoalRoundTrips() {
        val p = sample().copy(dailyWordGoal = null)
        assertEquals(null, p.toSnapshot(Instant.EPOCH).toUserProgress().dailyWordGoal)
    }
}
