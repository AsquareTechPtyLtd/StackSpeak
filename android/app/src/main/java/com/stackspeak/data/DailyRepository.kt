package com.stackspeak.data

import com.stackspeak.data.local.DailySetDao
import com.stackspeak.data.local.DailySetEntity
import com.stackspeak.domain.DailySetGenerator
import java.time.LocalDate
import java.time.ZoneId
import javax.inject.Inject
import javax.inject.Singleton

/** Today's word set + completion. Per-day, NOT synced — regenerates locally. */
data class DailySet(val dayString: String, val wordIds: List<String>, val completedWordIds: Set<String>) {
    val isComplete: Boolean get() = wordIds.isNotEmpty() && wordIds.all { it in completedWordIds }
}

@Singleton
class DailyRepository @Inject constructor(
    private val dao: DailySetDao,
    private val words: WordRepository,
    private val progress: ProgressRepository,
) {
    private fun today(zone: ZoneId) = LocalDate.now(zone).toString()

    /** Returns today's set, generating + persisting it (and advancing the cursor) on first call. */
    suspend fun todaysSet(zone: ZoneId = ZoneId.systemDefault()): DailySet {
        val day = today(zone)
        dao.get(day)?.takeIf { it.wordIds.isNotEmpty() }?.let { return it.toDomain() }

        val p = progress.ensureLoaded()
        val generated = DailySetGenerator.generate(words.allWords(), p)
        if (generated.wordIds.isEmpty()) return DailySet(day, emptyList(), emptySet())

        dao.upsert(DailySetEntity(day, generated.wordIds.joinToString(","), ""))
        progress.setCursor(generated.newCursor)
        return DailySet(day, generated.wordIds, emptySet())
    }

    /** Marks a word done; when the whole set is complete, credits the daily streak once. */
    suspend fun markCompleted(wordId: String, zone: ZoneId = ZoneId.systemDefault()): DailySet {
        val day = today(zone)
        val current = dao.get(day)?.toDomain() ?: todaysSet(zone)
        val completed = current.completedWordIds + wordId
        val updated = current.copy(completedWordIds = completed)
        dao.upsert(DailySetEntity(day, current.wordIds.joinToString(","), completed.joinToString(",")))
        if (updated.isComplete) progress.registerDailyCompletion()
        return updated
    }

    private fun DailySetEntity.toDomain() = DailySet(
        dayString = dayString,
        wordIds = if (wordIds.isEmpty()) emptyList() else wordIds.split(","),
        completedWordIds = if (completedWordIds.isEmpty()) emptySet() else completedWordIds.split(",").toSet(),
    )
}
