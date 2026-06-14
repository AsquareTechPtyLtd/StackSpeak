package com.stackspeak.domain

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * M1b parity: the deterministic primitives must reproduce the iOS golden vectors
 * in primitives.json exactly (FNV-1a hash, two-stream UUID, MMIX LCG sequences).
 */
class PrimitivesTest {

    private val fixture = Json.parseToJsonElement(Fixtures.read("primitives.json")).jsonObject

    @Test
    fun stableHashMatchesIos() {
        for (entry in fixture["stableHash"]!!.jsonArray) {
            val o = entry.jsonObject
            val input = o["input"]!!.jsonPrimitive.content
            val expected = o["stableHash"]!!.jsonPrimitive.content
            assertEquals("stableHash(\"$input\")", expected, stableHash(input).toString())
        }
    }

    @Test
    fun deterministicUuidMatchesIos() {
        for (entry in fixture["deterministicUUID"]!!.jsonArray) {
            val o = entry.jsonObject
            val input = o["input"]!!.jsonPrimitive.content
            val expected = o["uuid"]!!.jsonPrimitive.content
            assertEquals("deterministicUUID(\"$input\")", expected, deterministicUUID(input))
        }
    }

    @Test
    fun seededRandomSequencesMatchIos() {
        for (entry in fixture["seededRandom"]!!.jsonArray) {
            val o = entry.jsonObject
            val seed = o["seed"]!!.jsonPrimitive.content.toULong()
            val expected = o["sequence"]!!.jsonArray.map { it.jsonPrimitive.content }

            val gen = SeededRandomGenerator(seed)
            val got = expected.indices.map { gen.next().toString() }
            assertEquals("LCG sequence for seed $seed", expected, got)
        }
    }

    /** The fixture seeds are themselves stableHash(seedString) — verify that link. */
    @Test
    fun seedDerivesFromStableHashOfSeedString() {
        for (entry in fixture["seededRandom"]!!.jsonArray) {
            val o = entry.jsonObject
            val seedString = o["seedString"]!!.jsonPrimitive.content
            val seed = o["seed"]!!.jsonPrimitive.content
            assertEquals("stableHash(\"$seedString\")", seed, stableHash(seedString).toString())
        }
    }
}
