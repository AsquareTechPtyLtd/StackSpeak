import Foundation
import SwiftData

// Deterministic shuffle + daily-set selection machinery for WordService —
// split out per the <TypeName>+<Concern>.swift convention. The PRNG and hash
// are co-located: they exist only to make the shuffle reproducible.
extension WordService {
    /// Deterministic Fisher-Yates shuffle. Stable across launches because it uses
    /// a stable FNV-1a hash instead of Swift's randomized hashValue.
    func deterministicShuffle(_ words: [Word], seed: UUID) -> [Word] {
        // Canonical input order ensures the shuffle is reproducible regardless of DB fetch order.
        var result = words.sorted(using: KeyPathComparator(\.id.uuidString))
        var rng = SeededRandomGenerator(seed: stableHash(seed.uuidString + "v1"))
        for i in stride(from: result.count - 1, through: 1, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            result.swapAt(i, j)
        }
        return result
    }

    /// Walks the shuffled queue from `startIndex`, collects up to `count` qualifying words,
    /// and returns them along with the next cursor position.
    ///
    /// Interleaving algorithm: aims for one word from each of `count` DISTINCT
    /// categories (an open vocabulary — concepts, security, observability, …) for
    /// cognitive variety. When fewer than `count` distinct categories qualify (e.g.
    /// the user's stacks share categories), backfill from other words so the daily
    /// set always has `count` words.
    ///
    /// Internal access for unit testing.
    func selectQualifyingWords(
        from shuffled: [Word],
        startingAt startIndex: Int,
        userProgress: UserProgress,
        count: Int
    ) -> (words: [Word], nextCursor: Int) {
        guard !shuffled.isEmpty else { return ([], 0) }

        // Resolve the active stack set once (entitlement-aware) rather than per word.
        let activeStacks = userProgress.effectiveSelectedStacks

        // Interleaving for cognitive variety: take the first qualifying word from
        // each DISTINCT category (open vocabulary — concepts, security, …) until we
        // have `count` different categories. If fewer than `count` distinct
        // categories qualify, backfill with extra words so the set is always full.
        var firstPerCategory: [String: Word] = [:]
        var categoryOrder: [String] = []   // first-seen order → stable output
        var backfillPool: [Word] = []
        var cursor = startIndex % shuffled.count
        var seen = 0
        let limit = shuffled.count  // one full pass maximum

        while seen < limit {
            let word = shuffled[cursor]
            cursor = (cursor + 1) % shuffled.count
            seen += 1

            guard qualifies(word: word, for: userProgress, activeStacks: activeStacks) else { continue }

            if firstPerCategory[word.category] == nil {
                firstPerCategory[word.category] = word
                categoryOrder.append(word.category)
                // Enough distinct categories for a full, varied set — stop scanning.
                if categoryOrder.count >= count { break }
            } else {
                backfillPool.append(word)
            }
        }

        // One word per distinct category (first-seen order), then backfill to `count`.
        var result = categoryOrder.compactMap { firstPerCategory[$0] }
        var backfillIndex = 0
        while result.count < count && backfillIndex < backfillPool.count {
            result.append(backfillPool[backfillIndex])
            backfillIndex += 1
        }

        return (Array(result.prefix(count)), cursor)
    }

    private func qualifies(word: Word, for userProgress: UserProgress, activeStacks: Set<String>) -> Bool {
        !userProgress.masteredWordIds.contains(word.id) &&
        word.unlockLevel <= userProgress.level &&
        activeStacks.contains(word.stack)
    }
}

/// Linear Congruential Generator (Knuth's MMIX constants). Produces stable
/// output across Swift processes unlike String.hashValue. Seeded from the
/// FNV-1a `stableHash` below.
struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

/// FNV-1a hash over UTF-8 bytes. Deterministic across processes and platforms.
func stableHash(_ string: String) -> UInt64 {
    var hash: UInt64 = 14695981039346656037
    for byte in string.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 1099511628211
    }
    return hash
}
