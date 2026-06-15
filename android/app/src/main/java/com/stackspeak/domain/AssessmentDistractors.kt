package com.stackspeak.domain

import com.stackspeak.data.content.Word

/**
 * Builds the wrong multiple-choice options for an assessment, deterministically
 * (seeded by the user's shuffle seed + "assessment", mirroring iOS's parallel
 * seed). Excludes the same term and identical definitions. Not fixture-pinned
 * (no committed golden vector), but stable for a given seed + pool.
 */
object AssessmentDistractors {
    fun distractors(correct: Word, pool: List<Word>, shuffleSeed: String, count: Int = 3): List<String> {
        val candidates = pool.asSequence()
            .filter { it.id != correct.id && it.shortDefinition.isNotBlank() && it.shortDefinition != correct.shortDefinition }
            .map { it.shortDefinition }
            .distinct()
            .toMutableList()
        val rng = SeededRandomGenerator(stableHash(shuffleSeed + "assessment"))
        for (i in candidates.size - 1 downTo 1) {
            val j = (rng.next() % (i + 1).toULong()).toInt()
            val tmp = candidates[i]; candidates[i] = candidates[j]; candidates[j] = tmp
        }
        return candidates.take(count)
    }
}
