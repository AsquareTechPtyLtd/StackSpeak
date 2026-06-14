package com.stackspeak.domain

/**
 * Deterministic primitives — ported verbatim from iOS
 * (WordService+Selection.swift `stableHash`/`SeededRandomGenerator`,
 * Word.swift `deterministicUUID`). The whole reproducibility chain (shuffle,
 * daily selection, mnemonic→UUID mapping, SM-2 jitter) flows from these, so they
 * must match the iOS golden vectors in shared/test-fixtures/primitives.json
 * byte-for-byte. `ULong` gives the wrapping u64 arithmetic Swift's `&*`/`&+` do.
 */

private const val FNV_OFFSET = 14695981039346656037UL
private const val FNV_PRIME = 1099511628211UL

/** FNV-1a 64-bit hash over the string's UTF-8 bytes. */
fun stableHash(input: String): ULong {
    var hash = FNV_OFFSET
    for (b in input.encodeToByteArray()) {
        hash = hash xor b.toUByte().toULong()
        hash *= FNV_PRIME
    }
    return hash
}

/**
 * Linear Congruential Generator with Knuth's MMIX constants — stable across
 * processes/platforms (unlike `String.hashValue`). `next()` advances the state
 * and returns the new value.
 */
class SeededRandomGenerator(private var state: ULong) {
    fun next(): ULong {
        state = state * 6364136223846793005UL + 1442695040888963407UL
        return state
    }
}

/**
 * Maps a mnemonic id (e.g. "api-bas-0001-cache") to a stable UUID via two
 * FNV-1a streams (h2 seeded at offset+1 with an extra +7 per byte). The 16
 * little-endian bytes of h1 then h2 form the UUID; **no RFC version/variant
 * bits** are set. Returned UPPERCASE to match Swift's `.uuidString`.
 */
fun deterministicUUID(input: String): String {
    var h1 = FNV_OFFSET
    var h2 = FNV_OFFSET + 1UL
    for (b in input.encodeToByteArray()) {
        val bv = b.toUByte().toULong()
        h1 = h1 xor bv
        h1 *= FNV_PRIME
        h2 = h2 xor bv
        h2 = h2 * FNV_PRIME + 7UL
    }
    val bytes = ByteArray(16)
    for (i in 0..7) {
        bytes[i] = ((h1 shr (i * 8)) and 0xFFUL).toByte()
        bytes[8 + i] = ((h2 shr (i * 8)) and 0xFFUL).toByte()
    }
    val hex = buildString {
        for (b in bytes) append("%02X".format(b.toInt() and 0xFF))
    }
    return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-" +
        "${hex.substring(16, 20)}-${hex.substring(20, 32)}"
}

/**
 * The 16 raw bytes of a UUID string in standard (big-endian) order — byte 0 is
 * the first hex pair. Matches Swift's `withUnsafeBytes(of: uuid.uuid)` iteration
 * order, which SM-2's jitter hashes over.
 */
fun uuidBytes(uuid: String): ByteArray {
    val hex = uuid.replace("-", "")
    require(hex.length == 32) { "not a UUID: $uuid" }
    return ByteArray(16) { i ->
        ((Character.digit(hex[i * 2], 16) shl 4) or Character.digit(hex[i * 2 + 1], 16)).toByte()
    }
}
