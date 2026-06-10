import Testing
import Foundation
@testable import StackSpeak

@Suite("DailySet — Pro additional batches")
struct DailySetAdditionalBatchesTests {

    @Test("New DailySet has empty additionalBatches")
    func emptyByDefault() {
        let set = DailySet(dayString: "2026-04-27", wordIds: [UUID(), UUID()])
        #expect(set.additionalBatches.isEmpty)
        #expect(set.additionalBatchesStorage == "")
    }

    @Test("Appending a batch round-trips through storage")
    func appendBatchRoundtrip() {
        let set = DailySet(dayString: "2026-04-27", wordIds: [UUID()])
        let batch1 = (0..<5).map { _ in UUID() }
        let batch2 = (0..<3).map { _ in UUID() }
        set.appendAdditionalBatch(batch1)
        set.appendAdditionalBatch(batch2)

        #expect(set.additionalBatches.count == 2)
        #expect(set.additionalBatches[0] == batch1)
        #expect(set.additionalBatches[1] == batch2)
    }

    @Test("Empty batch is ignored")
    func appendEmptyBatchIgnored() {
        let set = DailySet(dayString: "2026-04-27", wordIds: [UUID()])
        set.appendAdditionalBatch([])
        #expect(set.additionalBatches.isEmpty)
    }

    @Test("allServedWordIds unions daily-5 and additional batches")
    func allServedUnion() {
        let primary = (0..<5).map { _ in UUID() }
        let extra = (0..<3).map { _ in UUID() }
        let set = DailySet(dayString: "2026-04-27", wordIds: primary)
        set.appendAdditionalBatch(extra)
        let served = set.allServedWordIds
        for id in primary { #expect(served.contains(id)) }
        for id in extra { #expect(served.contains(id)) }
        #expect(served.count == 8)
    }

    @Test("isStreakComplete is anchored to the daily-5, not additional batches")
    func streakUnaffectedByExtras() {
        let primary = (0..<5).map { _ in UUID() }
        let extra = (0..<5).map { _ in UUID() }
        let set = DailySet(dayString: "2026-04-27", wordIds: primary)
        set.appendAdditionalBatch(extra)

        // No words completed yet
        #expect(set.isStreakComplete == false)

        // Completing extras alone does NOT complete the streak
        for id in extra { set.markWordCompleted(id) }
        #expect(set.isStreakComplete == false)

        // Completing all 5 primary cards DOES complete the streak,
        // even though extra cards are completed.
        for id in primary { set.markWordCompleted(id) }
        #expect(set.isStreakComplete == true)
    }

    @Test("isStreakComplete remains true when only daily-5 is done and additional is empty")
    func streakWithoutExtras() {
        let primary = (0..<5).map { _ in UUID() }
        let set = DailySet(dayString: "2026-04-27", wordIds: primary)
        for id in primary { set.markWordCompleted(id) }
        #expect(set.isStreakComplete == true)
    }
}

@Suite("DailySet — completion gate")
struct DailySetCompletionTests {

    @Test("isComplete is false with no completions and for an empty set")
    func incompleteByDefault() {
        let primary = (0..<5).map { _ in UUID() }
        let set = DailySet(dayString: "2026-04-27", wordIds: primary)
        #expect(set.isComplete == false)

        let empty = DailySet(dayString: "2026-04-28", wordIds: [])
        #expect(empty.isComplete == false)
    }

    @Test("isComplete is false at 4 of 5 and flips true only on the 5th word")
    func gateRequiresAllFive() {
        let primary = (0..<5).map { _ in UUID() }
        let set = DailySet(dayString: "2026-04-27", wordIds: primary)

        for id in primary.prefix(4) { set.markWordCompleted(id) }
        #expect(set.isComplete == false)

        set.markWordCompleted(primary[4])
        #expect(set.isComplete == true)
    }

    @Test("4 base + 1 batch completion does NOT count as complete")
    func batchWordCannotSubstituteForBaseWord() {
        let primary = (0..<5).map { _ in UUID() }
        let extra = (0..<5).map { _ in UUID() }
        let set = DailySet(dayString: "2026-04-27", wordIds: primary)
        set.appendAdditionalBatch(extra)

        for id in primary.prefix(4) { set.markWordCompleted(id) }
        set.markWordCompleted(extra[0])

        // 5 completions total, but only 4 of the base 5 — must not be complete.
        #expect(set.isComplete == false)
    }

    @Test("isComplete stays true after extra batch completions push the count past 5")
    func extraCompletionsDoNotWedgeCompletion() {
        let primary = (0..<5).map { _ in UUID() }
        let extra = (0..<5).map { _ in UUID() }
        let set = DailySet(dayString: "2026-04-27", wordIds: primary)
        set.appendAdditionalBatch(extra)

        for id in primary { set.markWordCompleted(id) }
        #expect(set.isComplete == true)

        // A 6th completion (count 6 != 5) must not flip completion back off.
        set.markWordCompleted(extra[0])
        #expect(set.isComplete == true)
    }

    @Test("progress counts base cards only and never exceeds 1.0")
    func progressClampedToBaseCards() {
        let primary = (0..<5).map { _ in UUID() }
        let extra = (0..<5).map { _ in UUID() }
        let set = DailySet(dayString: "2026-04-27", wordIds: primary)
        set.appendAdditionalBatch(extra)

        #expect(set.progress == 0)

        for id in primary.prefix(2) { set.markWordCompleted(id) }
        set.markWordCompleted(extra[0])  // batch completion must not inflate progress
        #expect(set.progress == 0.4)

        for id in primary { set.markWordCompleted(id) }
        for id in extra { set.markWordCompleted(id) }
        #expect(set.progress == 1.0)
    }
}
