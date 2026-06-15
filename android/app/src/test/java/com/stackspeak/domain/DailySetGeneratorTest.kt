package com.stackspeak.domain

import com.stackspeak.data.UserProgress
import com.stackspeak.data.content.Word
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** M3: daily-set generation is deterministic for a seed, respects goal/level/
 *  mastery, and advances the cursor (queue matches iOS for a shared seed). */
class DailySetGeneratorTest {

    private fun word(name: String, category: String, level: Int = 1, stack: String = "test-stack") = Word(
        id = deterministicUUID(name), word = name, pronunciation = "", partOfSpeech = "",
        shortDefinition = "def", simpleDefinition = "", longDefinition = "", techContext = "",
        professionalContext = "", exampleSentence = "", etymology = "", connector = "",
        codeExampleLanguage = "", codeExampleCode = "", backingBookId = null, backingChapterId = null,
        backingCardId = null, stack = stack, unlockLevel = level, tags = emptyList(), category = category,
    )

    private val cats = listOf("concepts", "components", "processes", "patterns", "qualities", "security")
    private val words = (0 until 12).map { word("w-$it", cats[it % cats.size]) }
    private fun progress(goal: Int? = null, cursor: Int = 0, mastered: Set<String> = emptySet()) =
        UserProgress(shuffleSeed = "11111111-1111-1111-1111-111111111111", selectedStacks = setOf("test-stack"),
            level = 5, wordQueueCursor = cursor, dailyWordGoal = goal, masteredWordIds = mastered)

    @Test
    fun deterministicForSameSeedAndCursor() {
        val a = DailySetGenerator.generate(words, progress())
        val b = DailySetGenerator.generate(words, progress())
        assertEquals(a.wordIds, b.wordIds)
        assertEquals(a.newCursor, b.newCursor)
    }

    @Test
    fun respectsGoalAndAdvancesCursor() {
        val result = DailySetGenerator.generate(words, progress(goal = 5))
        assertEquals(5, result.wordIds.size)
        assertEquals(5, result.wordIds.toSet().size) // distinct
        assertTrue("cursor advanced", result.newCursor != 0 || result.wordIds.isEmpty())
    }

    @Test
    fun goalIsFlooredAtMinimum() {
        val result = DailySetGenerator.generate(words, progress(goal = 1))
        assertEquals(DailySetGenerator.MIN_DAILY_GOAL, result.wordIds.size)
    }

    @Test
    fun excludesMasteredWords() {
        val masteredId = words.first().id
        val result = DailySetGenerator.generate(words, progress(goal = 5, mastered = setOf(masteredId)))
        assertTrue("mastered word excluded", masteredId !in result.wordIds)
    }
}
