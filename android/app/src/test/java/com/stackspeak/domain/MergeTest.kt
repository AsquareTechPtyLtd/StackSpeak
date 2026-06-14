package com.stackspeak.domain

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * M1c parity: the per-field snapshot merge must reproduce merge.json exactly
 * (union+sort progress sets, last-write-wins preferences, paired rotation state,
 * per-record sub-merges).
 */
class MergeTest {

    private val cases = Json.parseToJsonElement(Fixtures.read("merge.json"))
        .jsonObject["cases"]!!.jsonArray

    @Test
    fun mergesMatchIos() {
        for (case in cases) {
            val o = case.jsonObject
            val name = o["name"]!!.jsonPrimitive.content
            val local = SnapshotJson.decodeFromJsonElement(ProgressSnapshot.serializer(), o["local"]!!)
            val remote = SnapshotJson.decodeFromJsonElement(ProgressSnapshot.serializer(), o["remote"]!!)
            val expected = SnapshotJson.decodeFromJsonElement(ProgressSnapshot.serializer(), o["expected"]!!)

            assertEquals("merge case '$name'", expected, mergeSnapshots(local, remote))
        }
    }

    /** Merge is commutative in the fields that should be, and idempotent. */
    @Test
    fun mergeIsIdempotent() {
        for (case in cases) {
            val o = case.jsonObject
            val local = SnapshotJson.decodeFromJsonElement(ProgressSnapshot.serializer(), o["local"]!!)
            val remote = SnapshotJson.decodeFromJsonElement(ProgressSnapshot.serializer(), o["remote"]!!)
            val merged = mergeSnapshots(local, remote)
            assertEquals("idempotent re-merge", merged, mergeSnapshots(merged, merged))
        }
    }
}
