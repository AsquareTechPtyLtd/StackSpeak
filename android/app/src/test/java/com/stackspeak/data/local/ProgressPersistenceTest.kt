package com.stackspeak.data.local

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.stackspeak.data.AssessmentRecord
import com.stackspeak.data.BookProgressRecord
import com.stackspeak.data.PracticedSentenceRecord
import com.stackspeak.data.ReviewRecord
import com.stackspeak.data.UserProgress
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.Instant

/**
 * M2: UserProgress persists across "relaunch" — save to Room, read back, identical.
 * Robolectric runs an in-memory Room DB on the JVM (SDK pinned to a Robolectric-
 * supported level; Room CRUD is SDK-agnostic).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ProgressPersistenceTest {

    private lateinit var db: AppDatabase
    private lateinit var store: ProgressLocalStore

    @Before
    fun setUp() {
        val ctx = ApplicationProvider.getApplicationContext<android.content.Context>()
        db = Room.inMemoryDatabaseBuilder(ctx, AppDatabase::class.java).allowMainThreadQueries().build()
        store = ProgressLocalStore(db.progressDao())
    }

    @After
    fun tearDown() = db.close()

    @Test
    fun savesAndReloadsIdentically() = runBlocking {
        val original = UserProgress(
            level = 8, currentStreak = 5, longestStreak = 12,
            lastCompletedDate = Instant.parse("2026-01-30T00:00:00Z"), didCompleteOnboarding = true,
            practicedWordIds = setOf("0326034C-C2B5-4C98-36E2-AF1800358A56", "D25E9FEB-D525-F60B-7F32-A769C12862F7"),
            masteredWordIds = setOf("0326034C-C2B5-4C98-36E2-AF1800358A56"),
            bookmarkedWordIds = setOf("D25E9FEB-D525-F60B-7F32-A769C12862F7"),
            wordsWithTwoCorrectIds = setOf("0326034C-C2B5-4C98-36E2-AF1800358A56"),
            wordsCreditedForLevelIds = setOf("0326034C-C2B5-4C98-36E2-AF1800358A56"),
            selectedStacks = setOf("api-basic", "gcp-basic"),
            shuffleSeed = "ABCDEF01-2345-6789-ABCD-EF0123456789", wordQueueCursor = 17, dailyWordGoal = 8,
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

        store.save(original)
        assertEquals(original, store.load())
    }

    @Test
    fun loadIsNullBeforeAnySave() = runBlocking {
        assertNull(store.load())
    }
}
