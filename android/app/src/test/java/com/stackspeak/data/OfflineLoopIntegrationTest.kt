package com.stackspeak.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.stackspeak.data.content.AssetReader
import com.stackspeak.data.local.AppDatabase
import com.stackspeak.data.local.ProgressLocalStore
import com.stackspeak.domain.Progression
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File

/**
 * M3 end-to-end (headless): drives the real repositories + Room + bundled assets
 * through the offline loop — load catalog → onboard → generate today's set →
 * practice every word → complete (streak) → assess (credit). Catches the
 * repository/DAO/generator wiring that unit tests and compile-time Hilt checks don't.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class OfflineLoopIntegrationTest {

    private lateinit var db: AppDatabase
    private lateinit var words: WordRepository
    private lateinit var progress: ProgressRepository
    private lateinit var daily: DailyRepository

    private val assetsDir: File = run {
        var dir: File? = File(System.getProperty("user.dir") ?: ".")
        while (dir != null && !File(dir, "app/src/main/assets").isDirectory && !File(dir, "src/main/assets").isDirectory) {
            dir = dir.parentFile
        }
        requireNotNull(dir)
        File(dir, if (File(dir, "src/main/assets").isDirectory) "src/main/assets" else "app/src/main/assets")
    }
    private val assetReader = AssetReader { File(assetsDir, it).readText() }

    @Before
    fun setUp() {
        val ctx = ApplicationProvider.getApplicationContext<android.content.Context>()
        db = Room.inMemoryDatabaseBuilder(ctx, AppDatabase::class.java).allowMainThreadQueries().build()
        words = WordRepository(assetReader)
        progress = ProgressRepository(ProgressLocalStore(db.progressDao()))
        daily = DailyRepository(db.dailySetDao(), words, progress)
    }

    @After
    fun tearDown() = db.close()

    @Test
    fun fullOfflineLoopWorks() = runBlocking {
        // Onboard with a real stack that has words.
        progress.completeOnboarding(setOf("api-basic"))

        // Today's set generates from the catalog and advances the cursor.
        val set = daily.todaysSet()
        assertTrue("daily set populated", set.wordIds.isNotEmpty())
        assertEquals("defaults to 5 words", 5, set.wordIds.size)
        assertTrue("cursor advanced", progress.ensureLoaded().wordQueueCursor != 0)

        // Practice + complete every word → the daily streak is credited once.
        set.wordIds.forEach { id ->
            progress.recordPractice(id, "my explanation of $id", "text")
            daily.markCompleted(id)
        }
        val afterComplete = progress.ensureLoaded()
        assertEquals("streak credited on full completion", 1, afterComplete.currentStreak)
        assertTrue("all words practiced", set.wordIds.all { it in afterComplete.practicedWordIds })

        // A correct assessment credits the word for leveling.
        val first = set.wordIds.first()
        progress.recordAssessment(first, isCorrect = true, selected = "x", correct = "x")
        val afterAssess = progress.ensureLoaded()
        assertTrue("first correct credits the word", first in afterAssess.wordsCreditedForLevelIds)
        assertTrue("at least one point", Progression.assessmentPoints(afterAssess) >= 1)

        // Reloading from Room (a fresh "relaunch") preserves everything.
        val reloaded = ProgressRepository(ProgressLocalStore(db.progressDao()))
        val persisted = reloaded.ensureLoaded()
        assertEquals(afterAssess.currentStreak, persisted.currentStreak)
        assertEquals(afterAssess.practicedWordIds, persisted.practicedWordIds)
        assertEquals(afterAssess.wordsCreditedForLevelIds, persisted.wordsCreditedForLevelIds)
    }
}
