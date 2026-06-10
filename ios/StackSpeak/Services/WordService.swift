import Foundation
import OSLog
import SwiftData

private let logger = Logger(category: "WordService")

@MainActor
final class WordService: WordRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadWordsFromBundle() async throws {
        // Load the index first
        guard let indexUrl = Bundle.main.url(forResource: "words-index", withExtension: "json") else {
            throw WordServiceError.indexFileNotFound
        }

        let indexData = try await Task.detached(priority: .userInitiated) {
            try Data(contentsOf: indexUrl)
        }.value

        let index = try JSONDecoder().decode(StacksIndex.self, from: indexData)

        var allWords: [(dto: WordDTO, stack: String)] = []

        for stackMeta in index.stacks {
            let stackFileName = stackMeta.file.replacingOccurrences(of: "stacks/", with: "")
                .replacingOccurrences(of: ".json", with: "")

            // xcodegen flattens Resources/stacks/*.json into the bundle root, so
            // look up by basename rather than via `subdirectory: "stacks"`.
            guard let stackUrl = Bundle.main.url(forResource: stackFileName, withExtension: "json") else {
                logger.warning("Stack file not found in bundle: \(stackFileName, privacy: .public).json")
                continue
            }

            let stackData: Data
            do {
                stackData = try await Task.detached(priority: .userInitiated) {
                    try Data(contentsOf: stackUrl)
                }.value
            } catch {
                logger.error("Failed to read \(stackFileName, privacy: .public).json: \(error.localizedDescription, privacy: .public)")
                continue
            }

            // Skip stack files that fail to decode rather than aborting the whole load.
            do {
                let stackFile = try JSONDecoder().decode(StackFileDTO.self, from: stackData)
                allWords.append(contentsOf: stackFile.words.map { ($0, stackFile.stack) })
            } catch {
                logger.error("Skipping \(stackFileName, privacy: .public).json — decode failed: \(error.localizedDescription, privacy: .public)")
                continue
            }
        }

        // Insert new words into the database, saving in chunks. SwiftData's
        // DefaultStore hits a "fatal logic error: temporary identifier remapped
        // during save" assertion when a single save resolves more than a few
        // hundred newly-inserted models at once. Saving every `batchSize` inserts
        // forces SwiftData to commit temp-IDs before the next batch begins.
        // Seed `seenIds` with what's already in the store, then add each ID as we
        // accept it this pass. This skips not just words already persisted but also
        // duplicate IDs *within the incoming bundle* — two entries resolving to the
        // same UUID would otherwise both insert and trip the `@Attribute(.unique)`
        // constraint at save time, failing a whole chunk (and partially committing
        // earlier ones) over a single content-authoring mistake.
        var seenIds = try fetchExistingWordIdSet()
        let batchSize = 200
        var insertedInBatch = 0
        for (dto, stack) in allWords {
            let wordId = UUID(uuidString: dto.id) ?? deterministicUUID(from: dto.id)
            guard seenIds.insert(wordId).inserted else {
                logger.warning("Skipping duplicate word id \(dto.id, privacy: .public) during bundle load")
                continue
            }
            let word = Word(from: dto, stack: stack)
            modelContext.insert(word)
            insertedInBatch += 1
            if insertedInBatch >= batchSize {
                try modelContext.save()
                insertedInBatch = 0
            }
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }

        // Count total words after loading
        let totalCount = try modelContext.fetchCount(FetchDescriptor<Word>())
        logger.info("Bundle load complete, total words in catalog: \(totalCount)")
    }

    func generateDailySet(for date: Date, userProgress: UserProgress) throws -> DailySet {
        let dayString = DailySet.dayString(from: date)

        let descriptor = FetchDescriptor<DailySet>(
            predicate: #Predicate { $0.dayString == dayString }
        )
        let existingSet = try modelContext.fetch(descriptor).first

        // If a previous call cached an empty DailySet (e.g. words hadn't finished loading
        // from the bundle yet), discard it and try again now that words may be available.
        if let existing = existingSet, !existing.wordIds.isEmpty {
            return existing
        }

        let allWords = try modelContext.fetch(FetchDescriptor<Word>())
        guard !allWords.isEmpty else {
            // Don't cache an empty set — return a transient one so the next call can retry
            // once the bundle finishes loading.
            return existingSet ?? DailySet(dayString: dayString, wordIds: [])
        }

        let shuffled = deterministicShuffle(allWords, seed: userProgress.shuffleSeed)
        let (selected, newCursor) = selectQualifyingWords(
            from: shuffled,
            startingAt: userProgress.wordQueueCursor,
            userProgress: userProgress,
            count: 5
        )

        // No qualifying words yet (e.g. user's selectedStacks haven't been finalized).
        // Don't cache — caller will retry.
        guard !selected.isEmpty else {
            let sampleStacks = Array(Set(allWords.prefix(50).map { $0.stack })).sorted()
            logger.warning("generateDailySet: 0 qualifying words. level=\(userProgress.level) selectedStacks=\(userProgress.selectedStacks.sorted().joined(separator: ","), privacy: .public) sampleWordStacks=\(sampleStacks.joined(separator: ","), privacy: .public) totalWords=\(allWords.count)")
            return existingSet ?? DailySet(dayString: dayString, wordIds: [])
        }

        userProgress.wordQueueCursor = newCursor

        // Reuse the existing empty record if present so the unique dayString constraint isn't violated.
        if let existing = existingSet {
            existing.wordIds = selected.map(\.id)
            try modelContext.save()
            return existing
        }

        let dailySet = DailySet(dayString: dayString, wordIds: selected.map(\.id))
        modelContext.insert(dailySet)
        try modelContext.save()
        return dailySet
    }

    func fetchWord(byId id: UUID) throws -> Word? {
        let descriptor = FetchDescriptor<Word>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchWords(matching query: String, filters: WordFilters) throws -> [Word] {
        // Apply text predicate at DB level when possible.
        let predicate: Predicate<Word>? = query.isEmpty ? nil : #Predicate { word in
            word.word.localizedStandardContains(query) ||
            word.shortDefinition.localizedStandardContains(query)
        }

        let descriptor = FetchDescriptor<Word>(predicate: predicate)
        var words = try modelContext.fetch(descriptor)

        if let stack = filters.stack {
            words = words.filter { $0.stack == stack.rawValue }
        }
        if let level = filters.level {
            words = words.filter { $0.unlockLevel == level }
        }
        if filters.masteredOnly, let ids = filters.masteredIds {
            words = words.filter { ids.contains($0.id) }
        }
        if filters.bookmarkedOnly, let ids = filters.bookmarkedIds {
            words = words.filter { ids.contains($0.id) }
        }

        return words.sorted(using: KeyPathComparator(\.word))
    }

    // MARK: - Private helpers

    private func fetchExistingWordIdSet() throws -> Set<UUID> {
        var descriptor = FetchDescriptor<Word>()
        descriptor.propertiesToFetch = [\.id]
        let words = try modelContext.fetch(descriptor)
        return Set(words.map(\.id))
    }

    /// Deterministic Fisher-Yates shuffle. Stable across launches because it uses
    /// a stable FNV-1a hash instead of Swift's randomized hashValue.
    private func deterministicShuffle(_ words: [Word], seed: UUID) -> [Word] {
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

struct WordFilters {
    var stack: WordStack?
    var level: Int?
    var masteredOnly: Bool = false
    var bookmarkedOnly: Bool = false
    var masteredIds: Set<UUID>?
    var bookmarkedIds: Set<UUID>?
}

enum WordServiceError: LocalizedError {
    case indexFileNotFound

    var errorDescription: String? {
        switch self {
        case .indexFileNotFound: return "words-index.json not found in app bundle"
        }
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
