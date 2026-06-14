package com.stackspeak.domain

/** Minimal word shape the rotation needs (ported from the selection-relevant
 *  fields of iOS `Word`). `id` is the UPPERCASE deterministic UUID string. */
data class SelectableWord(
    val id: String,
    val stack: String,
    val unlockLevel: Int,
    val category: String,
)

/** Result of a daily-set selection pass. */
data class SelectionResult(val words: List<SelectableWord>, val nextCursor: Int)

/**
 * Deterministic word rotation, ported from iOS `WordService+Selection.swift`.
 * `shuffleSeed` + `wordQueueCursor` sync across devices, so the queue must be
 * byte-identical to iOS. Pinned by `shuffle.json` + `selection.json`.
 */
object WordSelection {

    /**
     * Deterministic Fisher-Yates: canonicalize by `id` (uppercase UUID string),
     * then shuffle with `SeededRandomGenerator(stableHash(seedUuid + "v1"))`.
     */
    fun deterministicShuffle(words: List<SelectableWord>, seedUuid: String): List<SelectableWord> {
        // iOS canonicalizes with KeyPathComparator(\.id.uuidString), which for
        // String defaults to localizedStandard (numeric-aware) ordering — NOT
        // plain lexicographic. Match that or the shuffle diverges. (See
        // localizedStandardCompare; flagged as a latent locale-fragility in iOS.)
        val result = words.sortedWith(compareByLocalizedStandard { it.id }).toMutableList()
        val rng = SeededRandomGenerator(stableHash(seedUuid + "v1"))
        for (i in result.size - 1 downTo 1) {
            val j = (rng.next() % (i + 1).toULong()).toInt()
            val tmp = result[i]; result[i] = result[j]; result[j] = tmp
        }
        return result
    }

    /**
     * Walks the shuffled ring from [startCursor], taking the first qualifying word
     * per distinct category (first-seen order) until [count] categories, then
     * backfills from the leftover pool to reach [count]. Returns the advanced
     * cursor even on a full pass (so low-diversity stacks don't repeat daily).
     * [excludeIds] are skipped entirely (already-served words on grow/reconcile).
     */
    fun selectQualifyingWords(
        shuffled: List<SelectableWord>,
        startCursor: Int,
        level: Int,
        activeStacks: Set<String>,
        masteredIds: Set<String>,
        count: Int,
        excludeIds: Set<String> = emptySet(),
    ): SelectionResult {
        if (shuffled.isEmpty()) return SelectionResult(emptyList(), 0)

        val firstPerCategory = LinkedHashMap<String, SelectableWord>()
        val categoryOrder = ArrayList<String>()
        val backfillPool = ArrayList<SelectableWord>()
        var cursor = startCursor % shuffled.size
        var seen = 0
        var brokeEarly = false

        while (seen < shuffled.size) {
            val word = shuffled[cursor]
            cursor = (cursor + 1) % shuffled.size
            seen++

            if (word.id in excludeIds || !qualifies(word, level, activeStacks, masteredIds)) continue

            if (firstPerCategory[word.category] == null) {
                firstPerCategory[word.category] = word
                categoryOrder.add(word.category)
                if (categoryOrder.size >= count) {
                    brokeEarly = true
                    break
                }
            } else {
                backfillPool.add(word)
            }
        }

        val result = ArrayList(categoryOrder.map { firstPerCategory.getValue(it) })
        var i = 0
        while (result.size < count && i < backfillPool.size) {
            result.add(backfillPool[i]); i++
        }

        val nextCursor = if (brokeEarly) cursor else (startCursor + result.size) % shuffled.size
        return SelectionResult(result.take(count), nextCursor)
    }

    /** Daily-set eligibility: not mastered, unlocked at the level, in an active stack. */
    fun qualifies(word: SelectableWord, level: Int, activeStacks: Set<String>, masteredIds: Set<String>): Boolean =
        word.id !in masteredIds && word.unlockLevel <= level && word.stack in activeStacks
}

private fun <T> compareByLocalizedStandard(selector: (T) -> String): Comparator<T> =
    Comparator { a, b -> localizedStandardCompare(selector(a), selector(b)) }

/**
 * Mirrors Foundation's `localizedStandard` string comparison for the ASCII
 * uppercase-hex UUID strings the shuffle sorts: case-insensitive, with runs of
 * digits compared by numeric value (so "2…" sorts before "1407…"). This is what
 * iOS's `KeyPathComparator(\.id.uuidString)` does under the hood.
 *
 * NOTE (parity fragility): the iOS contract is locale-sensitive by accident.
 * For these hex strings it's stable across locales, but a plain byte-order sort
 * on both platforms would be a cleaner, locale-independent contract — worth
 * raising on the iOS side.
 */
internal fun localizedStandardCompare(a: String, b: String): Int {
    var i = 0
    var j = 0
    while (i < a.length && j < b.length) {
        val ca = a[i]
        val cb = b[j]
        if (ca.isDigit() && cb.isDigit()) {
            var ei = i; while (ei < a.length && a[ei].isDigit()) ei++
            var ej = j; while (ej < b.length && b[ej].isDigit()) ej++
            // Strip leading zeros, then compare by run length, then digit-by-digit.
            var sa = i; while (sa < ei - 1 && a[sa] == '0') sa++
            var sb = j; while (sb < ej - 1 && b[sb] == '0') sb++
            val lenA = ei - sa
            val lenB = ej - sb
            if (lenA != lenB) return lenA - lenB
            var k = 0
            while (k < lenA) {
                if (a[sa + k] != b[sb + k]) return a[sa + k].code - b[sb + k].code
                k++
            }
            // Equal numeric value — fewer leading zeros sorts first.
            if ((ei - i) != (ej - j)) return (ei - i) - (ej - j)
            i = ei; j = ej
        } else {
            val la = ca.lowercaseChar()
            val lb = cb.lowercaseChar()
            if (la != lb) return la.code - lb.code
            if (ca != cb) return ca.code - cb.code
            i++; j++
        }
    }
    return (a.length - i) - (b.length - j)
}
