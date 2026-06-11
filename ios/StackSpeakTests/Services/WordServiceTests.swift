import Testing
import Foundation
import SwiftData
@testable import StackSpeak

@Suite("SeededRandomGenerator — determinism")
struct SeededRandomGeneratorTests {

    @Test("Same seed produces identical sequence across calls")
    func sameSeedProducesSameSequence() {
        var gen1 = SeededRandomGenerator(seed: stableHash("test-seed-v1"))
        var gen2 = SeededRandomGenerator(seed: stableHash("test-seed-v1"))

        for _ in 0..<20 {
            #expect(gen1.next() == gen2.next())
        }
    }

    @Test("Different seeds produce different sequences")
    func differentSeedsProduceDifferentSequences() {
        var gen1 = SeededRandomGenerator(seed: stableHash("seed-A"))
        var gen2 = SeededRandomGenerator(seed: stableHash("seed-B"))

        let values1 = (0..<10).map { _ in gen1.next() }
        let values2 = (0..<10).map { _ in gen2.next() }
        #expect(values1 != values2)
    }
}

@Suite("stableHash — FNV-1a stability")
struct StableHashTests {

    @Test("Hash is stable — same input always returns same value")
    func hashIsStable() {
        #expect(stableHash("idempotent") == stableHash("idempotent"))
        #expect(stableHash("") == stableHash(""))
        #expect(stableHash("abc123") == stableHash("abc123"))
    }

    @Test("Different inputs produce different hashes")
    func differentInputsAreDifferent() {
        #expect(stableHash("abc") != stableHash("abd"))
        #expect(stableHash("v1") != stableHash("v2"))
    }

    @Test("Hash is non-zero for non-empty input")
    func hashIsNonZero() {
        #expect(stableHash("anything") != 0)
    }
}

@Suite("WordService — stale word cleanup")
@MainActor
struct WordServiceStaleCleanupTests {

    // Returns the container too: ModelContext does not retain its container,
    // and inserting into a context whose container has deallocated is a
    // SwiftData fatalError.
    private func makeService() throws -> (WordService, ModelContainer) {
        let schema = Schema([Word.self, UserProgress.self, DailySet.self,
                             ReviewState.self, AssessmentResult.self, PracticedSentence.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return (WordService(modelContext: container.mainContext), container)
    }

    private func insertWord(_ id: UUID, into context: ModelContext) {
        let word = Word(
            id: id,
            word: "term-\(id.uuidString.prefix(4))",
            pronunciation: "/test/",
            partOfSpeech: "noun",
            shortDefinition: "Test",
            simpleDefinition: "Test",
            longDefinition: "Test",
            techContext: "Test",
            exampleSentence: "Test",
            etymology: "Test",
            connector: "Test",
            codeExampleLanguage: "swift",
            codeExampleCode: "let x = 1",
            stack: "test-stack",
            unlockLevel: 1,
            tags: [],
            category: "concepts"
        )
        context.insert(word)
    }

    @Test("Words absent from the bundle are deleted; current ones survive")
    func deletesOnlyStaleWords() throws {
        let (service, container) = try makeService()
        let context = container.mainContext
        let current = UUID()
        let stale = UUID()
        insertWord(current, into: context)
        insertWord(stale, into: context)
        try context.save()

        try service.deleteStaleWords(notIn: [current])

        let remaining = try context.fetch(FetchDescriptor<Word>())
        #expect(remaining.map(\.id) == [current])
    }

    @Test("An empty bundle id set never deletes anything (failed load guard)")
    func emptyBundleIsNoOp() throws {
        let (service, container) = try makeService()
        let context = container.mainContext
        insertWord(UUID(), into: context)
        insertWord(UUID(), into: context)
        try context.save()

        try service.deleteStaleWords(notIn: [])

        #expect(try context.fetchCount(FetchDescriptor<Word>()) == 2)
    }

    @Test("No-op when every persisted word is still in the bundle")
    func allCurrentIsNoOp() throws {
        let (service, container) = try makeService()
        let context = container.mainContext
        let ids = [UUID(), UUID(), UUID()]
        for id in ids { insertWord(id, into: context) }
        try context.save()

        try service.deleteStaleWords(notIn: Set(ids))

        #expect(try context.fetchCount(FetchDescriptor<Word>()) == 3)
    }
}
