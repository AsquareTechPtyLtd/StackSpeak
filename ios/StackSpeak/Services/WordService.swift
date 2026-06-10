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
}

enum WordServiceError: LocalizedError {
    case indexFileNotFound

    var errorDescription: String? {
        switch self {
        case .indexFileNotFound: return "words-index.json not found in app bundle"
        }
    }
}
