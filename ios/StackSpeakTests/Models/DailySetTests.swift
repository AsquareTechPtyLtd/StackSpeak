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
