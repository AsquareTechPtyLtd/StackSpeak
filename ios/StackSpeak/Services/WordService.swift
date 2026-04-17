import Foundation
import SwiftData

@MainActor
final class WordService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadWordsFromBundle() async throws {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json") else {
            throw WordServiceError.bundleFileNotFound
        }

        let data = try Data(contentsOf: url)
        let database = try JSONDecoder().decode(WordsDatabase.self, from: data)

        let existingWordIds = try fetchExistingWordIds()
        let newWords = database.words.filter { !existingWordIds.contains($0.id) }

        for word in newWords {
            modelContext.insert(word)
        }

        try modelContext.save()
    }

    func generateDailySet(for date: Date, userProgress: UserProgress) throws -> DailySet {
        let startOfDay = Calendar.current.startOfDay(for: date)

        let descriptor = FetchDescriptor<DailySet>(
            predicate: #Predicate { $0.date == startOfDay }
        )

        if let existingSet = try modelContext.fetch(descriptor).first {
            return existingSet
        }

        let availableWords = try fetchUnlockedWords(for: userProgress)
        let selectedWords = selectWords(from: availableWords, seed: userProgress.shuffleSeed, date: date, count: 5)

        let dailySet = DailySet(date: startOfDay, wordIds: selectedWords.map(\.id))
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
        var predicate: Predicate<Word>?

        if !query.isEmpty {
            predicate = #Predicate { word in
                word.word.localizedStandardContains(query) ||
                word.shortDefinition.localizedStandardContains(query) ||
                word.tags.contains(where: { $0.localizedStandardContains(query) })
            }
        }

        let descriptor = FetchDescriptor<Word>(predicate: predicate)
        var words = try modelContext.fetch(descriptor)

        if let stack = filters.stack {
            words = words.filter { $0.stack == stack }
        }

        if let level = filters.level {
            words = words.filter { $0.unlockLevel == level }
        }

        return words.sorted { $0.word < $1.word }
    }

    private func fetchExistingWordIds() throws -> Set<UUID> {
        let descriptor = FetchDescriptor<Word>()
        let words = try modelContext.fetch(descriptor)
        return Set(words.map(\.id))
    }

    private func fetchUnlockedWords(for userProgress: UserProgress) throws -> [Word] {
        let descriptor = FetchDescriptor<Word>(
            predicate: #Predicate { word in
                word.unlockLevel <= userProgress.level
            }
        )

        let words = try modelContext.fetch(descriptor)
        return words.filter { word in
            !userProgress.masteredWordIds.contains(word.id) &&
            userProgress.selectedStacks.contains(word.stack.rawValue)
        }
    }

    private func selectWords(from words: [Word], seed: UUID, date: Date, count: Int) -> [Word] {
        let dateComponent = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let combinedSeed = seed.uuidString + String(dateComponent)

        var generator = SeededRandomGenerator(seed: combinedSeed.hashValue)
        let shuffled = words.shuffled(using: &generator)

        return Array(shuffled.prefix(count))
    }
}

struct WordFilters {
    var stack: WordStack?
    var level: Int?
    var masteredOnly: Bool = false
    var bookmarkedOnly: Bool = false
}

enum WordServiceError: LocalizedError {
    case bundleFileNotFound
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .bundleFileNotFound:
            return "words.json not found in app bundle"
        case .decodingFailed:
            return "Failed to decode words.json"
        }
    }
}

struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        self.state = UInt64(truncatingIfNeeded: seed)
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
