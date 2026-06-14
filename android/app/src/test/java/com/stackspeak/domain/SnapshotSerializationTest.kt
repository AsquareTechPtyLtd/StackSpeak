package com.stackspeak.domain

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * M1a parity: [ProgressSnapshot] must decode the iOS-generated snapshot fixtures
 * and re-encode to the same shape — proving Android serializes the identical
 * cross-platform contract (dates without fractional seconds, omitted nil
 * optionals, schema-v2 dailyWordGoal tolerance).
 */
class SnapshotSerializationTest {

    private fun decode(name: String): ProgressSnapshot =
        SnapshotJson.decodeFromString(ProgressSnapshot.serializer(), Fixtures.read("snapshots/$name"))

    @Test
    fun decodesNewUser() {
        val s = decode("new-user.json")
        assertEquals(1, s.schemaVersion)
        assertEquals(1, s.level)
        assertEquals(listOf("api-basic"), s.selectedStacks)
        assertEquals("ABCDEF01-2345-6789-ABCD-EF0123456789", s.shuffleSeed)
        assertNull("pre-v2 snapshot omits dailyWordGoal", s.dailyWordGoal)
        assertNull(s.lastCompletedDate)
        assertTrue(s.reviewStates.isEmpty())
    }

    @Test
    fun decodesRichSnapshot() {
        val s = decode("rich.json")
        assertEquals(8, s.level)
        assertEquals(5, s.currentStreak)
        assertEquals(12, s.longestStreak)
        assertEquals(17, s.wordQueueCursor)
        assertEquals(2, s.reviewStates.size)
        assertEquals(2.6, s.reviewStates[0].easinessFactor, 0.0)
        assertEquals(1, s.bookProgress.size)
        assertEquals(listOf("api-ch03-c001", "api-ch03-c002"), s.bookProgress[0].completedCardIds)
    }

    /** Round-trip is lossless: decode → encode → decode yields the same object. */
    @Test
    fun roundTripIsLossless() {
        for (name in listOf("new-user.json", "rich.json", "nil-optionals.json")) {
            val original = decode(name)
            val reDecoded = SnapshotJson.decodeFromString(
                ProgressSnapshot.serializer(),
                SnapshotJson.encodeToString(ProgressSnapshot.serializer(), original)
            )
            assertEquals("round-trip $name", original, reDecoded)
        }
    }

    /** Semantic parity: re-encoded JSON parses to the same structure as the fixture. */
    @Test
    fun reEncodeMatchesFixtureStructurally() {
        for (name in listOf("new-user.json", "rich.json", "nil-optionals.json")) {
            val fixtureElement = Json.parseToJsonElement(Fixtures.read("snapshots/$name"))
            val reEncoded = Json.parseToJsonElement(
                SnapshotJson.encodeToString(ProgressSnapshot.serializer(), decode(name))
            )
            assertEquals("structural parity $name", fixtureElement, reEncoded)
        }
    }

    /** Nil optionals must be omitted keys, never null. */
    @Test
    fun nilOptionalsAreOmitted() {
        val encoded = SnapshotJson.encodeToString(ProgressSnapshot.serializer(), decode("nil-optionals.json"))
        val obj = Json.parseToJsonElement(encoded).jsonObject
        assertFalse("lastCompletedDate omitted", obj.containsKey("lastCompletedDate"))
        assertFalse("dailyWordGoal omitted (pre-v2)", obj.containsKey("dailyWordGoal"))

        val review = (obj["reviewStates"] as kotlinx.serialization.json.JsonArray)[0].jsonObject
        assertFalse("review.lastReviewedAt omitted", review.containsKey("lastReviewedAt"))

        val book = (obj["bookProgress"] as kotlinx.serialization.json.JsonArray)[0].jsonObject
        assertFalse("book.currentChapterId omitted", book.containsKey("currentChapterId"))
        assertFalse("book.currentCardId omitted", book.containsKey("currentCardId"))
    }

    /** Dates encode with no fractional seconds and a Z suffix. */
    @Test
    fun datesHaveNoFractionalSeconds() {
        val encoded = SnapshotJson.encodeToString(ProgressSnapshot.serializer(), decode("rich.json"))
        val isoNoFraction = Regex("""\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z""")
        // every date-looking value matches the no-fraction shape
        val anyDate = Regex("""\d{4}-\d{2}-\d{2}T[\d:.]+Z?""")
        for (m in anyDate.findAll(encoded)) {
            assertTrue("date '${m.value}' has no fractional seconds", isoNoFraction.matches(m.value))
        }
    }

    @Test
    fun dailyWordGoalRoundTripsWhenPresent() {
        val base = decode("new-user.json").copy(dailyWordGoal = 8, schemaVersion = 2)
        val encoded = SnapshotJson.encodeToString(ProgressSnapshot.serializer(), base)
        assertTrue("dailyWordGoal present when set", encoded.contains("\"dailyWordGoal\":8"))
        val back = SnapshotJson.decodeFromString(ProgressSnapshot.serializer(), encoded)
        assertEquals(8, back.dailyWordGoal)
    }
}
