package com.stackspeak.domain

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant

/**
 * M1c parity: SM-2 transitions must match sm2.json across every grade path
 * (all-good, all-easy, lapse-then-recover, immediate-fail) — EF/interval/reps
 * and the jittered due date.
 */
class Sm2Test {

    private val sequences = Json.parseToJsonElement(Fixtures.read("sm2.json"))
        .jsonObject["sequences"]!!.jsonArray

    @Test
    fun transitionsMatchIos() {
        for (seq in sequences) {
            val o = seq.jsonObject
            val name = o["name"]!!.jsonPrimitive.content
            val wordId = o["wordId"]!!.jsonPrimitive.content
            val appliedAt = Instant.parse(o["appliedAt"]!!.jsonPrimitive.content)
            val grades = o["grades"]!!.jsonArray.map { it.jsonPrimitive.int }

            // initial state
            var state = Sm2.initial(appliedAt)
            assertState("$name/initial", o["initial"]!!.jsonObject, state, expectLastReviewed = false)

            // after each grade
            val afterEach = o["afterEachGrade"]!!.jsonArray
            grades.forEachIndexed { i, grade ->
                state = Sm2.updateAfterReview(state, wordId, grade, appliedAt)
                assertState("$name/grade[$i]=$grade", afterEach[i].jsonObject, state, expectLastReviewed = true)
            }
        }
    }

    private fun assertState(
        label: String,
        expected: kotlinx.serialization.json.JsonObject,
        actual: Sm2State,
        expectLastReviewed: Boolean,
    ) {
        assertEquals("$label EF", expected["easinessFactor"]!!.jsonPrimitive.content.toDouble(), actual.easinessFactor, 1e-9)
        assertEquals("$label interval", expected["interval"]!!.jsonPrimitive.int, actual.interval)
        assertEquals("$label repetitions", expected["repetitions"]!!.jsonPrimitive.int, actual.repetitions)
        assertEquals("$label dueDate", Instant.parse(expected["dueDate"]!!.jsonPrimitive.content), actual.dueDate)
        if (expectLastReviewed) {
            assertEquals("$label lastReviewedAt", Instant.parse(expected["lastReviewedAt"]!!.jsonPrimitive.content), actual.lastReviewedAt)
        }
    }
}
