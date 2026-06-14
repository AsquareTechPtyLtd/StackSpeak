import Testing
import Foundation
import SwiftData
@testable import StackSpeak

/// Covers the daily-goal / stack-reconcile reshaping in `WordService+DailySet`.
/// These mutate today's set and advance the queue cursor — CLAUDE.md lists word
/// rotation + daily-set completion as must-test paths.
@Suite("WordService — daily goal & reconcile")
@MainActor
struct WordServiceDailySetTests {

    // ModelContext doesn't retain its container; return it so it outlives the test.
    private func makeService() throws -> (WordService, ModelContainer) {
        let schema = Schema([Word.self, UserProgress.self, DailySet.self,
                             ReviewState.self, AssessmentResult.self, PracticedSentence.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return (WordService(modelContext: container.mainContext), container)
    }

    @discardableResult
    private func insertWord(_ id: UUID, stack: String, category: String,
                            into context: ModelContext) -> UUID {
        context.insert(Word(
            id: id, word: "term-\(id.uuidString.prefix(4))", pronunciation: "/test/",
            partOfSpeech: "noun", shortDefinition: "Test", simpleDefinition: "Test",
            longDefinition: "Test", techContext: "Test", exampleSentence: "Test",
            etymology: "Test", connector: "Test", codeExampleLanguage: "swift",
            codeExampleCode: "let x = 1", stack: stack, unlockLevel: 1,
            tags: [], category: category))
        return id
    }

    private func makeProgress(stacks: Set<String>, goal: Int, in context: ModelContext) -> UserProgress {
        let p = UserProgress()
        p.level = 99
        p.selectedStacks = stacks
        p.dailyWordGoal = goal
        context.insert(p)
        return p
    }

    @discardableResult
    private func makeSet(_ ids: [UUID], completed: Set<UUID> = [], in context: ModelContext) throws -> DailySet {
        let set = DailySet(dayString: DailySet.todayString(), wordIds: ids)
        for id in completed { set.markWordCompleted(id) }
        context.insert(set)
        try context.save()
        return set
    }

    @Test("Shrink keeps completed words even when they sit past the new cutoff")
    func shrinkPreservesCompletedWords() throws {
        let (service, container) = try makeService()
        let ctx = container.mainContext
        let ids = (0..<8).map { insertWord(UUID(), stack: "ds-stack", category: "cat-\($0)", into: ctx) }
        let progress = makeProgress(stacks: ["ds-stack"], goal: 8, in: ctx)
        // Completed words live at the tail (indices 6, 7) — exactly where naive
        // prefix-trimming would drop them.
        try makeSet(ids, completed: [ids[6], ids[7]], in: ctx)

        let result = try service.setDailyWordGoal(5, userProgress: progress)

        #expect(result.wordIds.count == 5)
        #expect(result.wordIds.contains(ids[6]))
        #expect(result.wordIds.contains(ids[7]))
        // Completed records stay consistent with what's in the set.
        #expect(result.completedWordIds.isSubset(of: Set(result.wordIds)))
    }

    @Test("Grow appends fresh qualifying words, preserves the original prefix, no duplicates")
    func growAppendsWithoutDuplicates() throws {
        let (service, container) = try makeService()
        let ctx = container.mainContext
        let all = (0..<10).map { insertWord(UUID(), stack: "ds-stack", category: "cat-\($0)", into: ctx) }
        let progress = makeProgress(stacks: ["ds-stack"], goal: 5, in: ctx)
        let original = Array(all.prefix(5))
        try makeSet(original, in: ctx)

        let result = try service.setDailyWordGoal(8, userProgress: progress)

        #expect(result.wordIds.count == 8)
        #expect(Set(result.wordIds).count == 8)                 // no duplicates
        #expect(Array(result.wordIds.prefix(5)) == original)    // original kept up front
    }

    @Test("Grow on an exhausted pool leaves the set and cursor untouched")
    func growExhaustedPoolNoOp() throws {
        let (service, container) = try makeService()
        let ctx = container.mainContext
        let all = (0..<4).map { insertWord(UUID(), stack: "ds-stack", category: "cat-\($0)", into: ctx) }
        let progress = makeProgress(stacks: ["ds-stack"], goal: 4, in: ctx)
        progress.wordQueueCursor = 2
        try makeSet(all, in: ctx)

        let result = try service.setDailyWordGoal(8, userProgress: progress)

        #expect(result.wordIds.count == 4)            // can't grow — every word already served
        #expect(progress.wordQueueCursor == 2)        // cursor must not advance past nothing
    }

    @Test("Reconcile drops deselected incomplete words but keeps completed ones, backfilling to goal")
    func reconcileDropsDeselectedKeepsCompleted() throws {
        let (service, container) = try makeService()
        let ctx = container.mainContext
        let a = (0..<3).map { insertWord(UUID(), stack: "stack-a", category: "a-\($0)", into: ctx) }
        let b = (0..<3).map { insertWord(UUID(), stack: "stack-b", category: "b-\($0)", into: ctx) }
        // Start with both stacks selected; today's set draws from both.
        let progress = makeProgress(stacks: ["stack-a", "stack-b"], goal: 4, in: ctx)
        try makeSet([a[0], a[1], b[0], b[1]], completed: [b[0]], in: ctx)

        // User deselects stack-b.
        progress.selectedStacks = ["stack-a"]
        let result = try #require(try service.reconcileTodaysSetWithSelection(userProgress: progress))

        #expect(result.wordIds.contains(b[0]))        // completed — always kept
        #expect(!result.wordIds.contains(b[1]))       // incomplete + deselected — dropped
        #expect(result.wordIds.contains(a[0]))
        #expect(result.wordIds.contains(a[1]))
        #expect(result.wordIds.count == 4)            // backfilled from stack-a to the goal
    }
}
