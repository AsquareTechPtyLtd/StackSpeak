package com.stackspeak.domain

import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/**
 * The one configured [Json] for [ProgressSnapshot] sync I/O. Matches the iOS
 * backend's wire format:
 *  - `explicitNulls = false` → nil optionals become omitted keys (Swift's
 *    `encodeIfPresent`), not `null`.
 *  - `ignoreUnknownKeys = true` → pre-v2 and future fields decode without error.
 *  - compact output (no pretty-print) — the committed fixtures are pretty-printed
 *    for diffs, but the pushed wire format is compact; parity is semantic, not
 *    byte-for-byte whitespace.
 */
val SnapshotJson: Json = Json {
    explicitNulls = false
    ignoreUnknownKeys = true
    encodeDefaults = false
}

/**
 * ISO-8601 with **no fractional seconds** and a `Z` suffix (e.g.
 * `2026-01-01T00:00:00Z`) — the exact shape of the backend's
 * `JSONEncoder.dateEncodingStrategy = .iso8601`. Truncating to seconds on encode
 * guarantees no sub-second precision leaks (which would also break the
 * practicedSentences whole-second dedup contract).
 */
object InstantIso8601Serializer : KSerializer<Instant> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("Instant", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: Instant) {
        encoder.encodeString(
            DateTimeFormatter.ISO_INSTANT.format(value.truncatedTo(ChronoUnit.SECONDS))
        )
    }

    override fun deserialize(decoder: Decoder): Instant =
        Instant.parse(decoder.decodeString())
}
