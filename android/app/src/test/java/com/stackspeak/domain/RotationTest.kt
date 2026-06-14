package com.stackspeak.domain

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * M1d parity: deterministic shuffle (shuffle.json) and category-interleaving
 * selection with backfill + mastered-exclusion + cursor advance (selection.json).
 * Selection words are reconstructed exactly as the iOS fixture generator built
 * them (deterministicUUID(name) + assigned categories).
 */
class RotationTest {

    private fun word(name: String, category: String) =
        SelectableWord(deterministicUUID(name), stack = "test-stack", unlockLevel = 1, category = category)

    @Test
    fun shuffleMatchesIos() {
        val cases = Json.parseToJsonElement(Fixtures.read("shuffle.json")).jsonObject["cases"]!!.jsonArray
        for (case in cases) {
            val o = case.jsonObject
            val seed = o["seed"]!!.jsonPrimitive.content
            val inputIds = o["inputIds"]!!.jsonArray.map { it.jsonPrimitive.content }
            val expected = o["outputIds"]!!.jsonArray.map { it.jsonPrimitive.content }

            val words = inputIds.map { SelectableWord(it, "test-stack", 1, "concepts") }
            val got = WordSelection.deterministicShuffle(words, seed).map { it.id }
            assertEquals("shuffle '${o["name"]!!.jsonPrimitive.content}'", expected, got)
        }
    }

    @Test
    fun selectionMatchesIos() {
        val cats = listOf("concepts", "components", "processes", "patterns", "qualities")
        val byName = Json.parseToJsonElement(Fixtures.read("selection.json"))
            .jsonObject["cases"]!!.jsonArray.associateBy { it.jsonObject["name"]!!.jsonPrimitive.content }

        // Reconstruct each case's words exactly like FixtureGenerationTests.swift.
        val balanced = cats.mapIndexed { i, c -> word("bal-$i", c) }
        val backfill = (1..8).map { word("bf-$it", if (it % 2 == 0) "concepts" else "components") }
        val withMastered = (1..6).map { word("ms-$it", cats[it % cats.size]) }

        data class Case(val name: String, val words: List<SelectableWord>, val mastered: Set<String>)
        val cases = listOf(
            Case("balanced", balanced, emptySet()),
            Case("backfill-two-categories", backfill, emptySet()),
            Case("excludes-mastered", withMastered, setOf(deterministicUUID("ms-1"))),
        )

        for (c in cases) {
            val fx = byName.getValue(c.name).jsonObject
            // sanity: our reconstructed ids match the fixture's recorded input order
            assertEquals(
                "${c.name} inputWordIds",
                fx["inputWordIds"]!!.jsonArray.map { it.jsonPrimitive.content },
                c.words.map { it.id },
            )

            val result = WordSelection.selectQualifyingWords(
                shuffled = c.words,
                startCursor = 0,
                level = 5,
                activeStacks = setOf("test-stack"),
                masteredIds = c.mastered,
                count = 5,
            )
            assertEquals(
                "${c.name} selectedWordIds",
                fx["selectedWordIds"]!!.jsonArray.map { it.jsonPrimitive.content },
                result.words.map { it.id },
            )
            assertEquals(
                "${c.name} nextCursor",
                fx["nextCursor"]!!.jsonPrimitive.content.toInt(),
                result.nextCursor,
            )
        }
    }
}
