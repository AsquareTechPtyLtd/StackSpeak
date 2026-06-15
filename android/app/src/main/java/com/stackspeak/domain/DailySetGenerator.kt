package com.stackspeak.domain

import com.stackspeak.data.UserProgress
import com.stackspeak.data.content.Word

/** Today's generated set: the chosen word ids and the advanced queue cursor. */
data class GeneratedDailySet(val wordIds: List<String>, val newCursor: Int)

/**
 * Generates today's word set — ports iOS `WordService.generateDailySet`: shuffle
 * the catalog by the user's seed, then category-interleave-select `goal` qualifying
 * words from the cursor. Returns the advanced cursor so the queue moves forward.
 */
object DailySetGenerator {
    const val MIN_DAILY_GOAL = 3

    fun effectiveGoal(progress: UserProgress): Int =
        maxOf(MIN_DAILY_GOAL, progress.dailyWordGoal ?: 5)

    fun generate(words: List<Word>, progress: UserProgress): GeneratedDailySet {
        if (words.isEmpty()) return GeneratedDailySet(emptyList(), progress.wordQueueCursor)
        val selectable = words.map { it.toSelectable() }
        val shuffled = WordSelection.deterministicShuffle(selectable, progress.shuffleSeed)
        val result = WordSelection.selectQualifyingWords(
            shuffled = shuffled,
            startCursor = progress.wordQueueCursor,
            level = progress.level,
            activeStacks = progress.selectedStacks,
            masteredIds = progress.masteredWordIds,
            count = effectiveGoal(progress),
        )
        return GeneratedDailySet(result.words.map { it.id }, result.nextCursor)
    }
}

fun Word.toSelectable(): SelectableWord =
    SelectableWord(id = id, stack = stack, unlockLevel = unlockLevel, category = category)
