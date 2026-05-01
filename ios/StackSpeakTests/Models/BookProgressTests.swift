import Testing
import Foundation
@testable import StackSpeak

@Suite("BookProgress — per-book streak")
struct BookProgressStreakTests {

    @Test("Reading the same day twice is a no-op (streak does not advance)")
    func sameDayNoOp() {
        let p = BookProgress(bookId: "book-a")
        p.recordReadDay(today: "2026-04-27", yesterday: "2026-04-26")
        p.recordReadDay(today: "2026-04-27", yesterday: "2026-04-26")
        #expect(p.currentStreakDays == 1)
        #expect(p.longestStreakDays == 1)
    }

    @Test("Consecutive days increment the streak")
    func consecutiveDaysIncrement() {
        let p = BookProgress(bookId: "book-a")
        p.recordReadDay(today: "2026-04-25", yesterday: "2026-04-24")
        p.recordReadDay(today: "2026-04-26", yesterday: "2026-04-25")
        p.recordReadDay(today: "2026-04-27", yesterday: "2026-04-26")
        #expect(p.currentStreakDays == 3)
        #expect(p.longestStreakDays == 3)
    }

    @Test("A 2+ day gap resets currentStreakDays back to 1")
    func gapResets() {
        let p = BookProgress(bookId: "book-a")
        p.recordReadDay(today: "2026-04-20", yesterday: "2026-04-19")
        p.recordReadDay(today: "2026-04-21", yesterday: "2026-04-20")
        p.recordReadDay(today: "2026-04-21", yesterday: "2026-04-20") // idempotent
        // Now skip a day
        p.recordReadDay(today: "2026-04-25", yesterday: "2026-04-24")
        #expect(p.currentStreakDays == 1)
        #expect(p.longestStreakDays == 2)
    }

    @Test("longestStreakDays only ever monotonically increases")
    func longestMonotonic() {
        let p = BookProgress(bookId: "book-a")
        p.recordReadDay(today: "2026-04-01", yesterday: "2026-03-31")
        p.recordReadDay(today: "2026-04-02", yesterday: "2026-04-01")
        p.recordReadDay(today: "2026-04-03", yesterday: "2026-04-02")
        #expect(p.longestStreakDays == 3)
        // Reset due to gap
        p.recordReadDay(today: "2026-04-10", yesterday: "2026-04-09")
        #expect(p.currentStreakDays == 1)
        #expect(p.longestStreakDays == 3)
    }
}

@Suite("BookProgress — completed cards")
struct BookProgressCompletionTests {

    @Test("markCardCompleted is idempotent")
    func idempotentCompletion() {
        let p = BookProgress(bookId: "book-a")
        p.markCardCompleted("c1")
        p.markCardCompleted("c1")
        p.markCardCompleted("c2")
        #expect(p.completedCardIds == ["c1", "c2"])
    }

    @Test("completedCardIds round-trips through CSV storage")
    func storageRoundtrip() {
        let p = BookProgress(bookId: "book-a")
        p.completedCardIds = ["alpha", "beta", "gamma"]
        let restored = p.completedCardIds
        #expect(restored == ["alpha", "beta", "gamma"])
    }

    @Test("Empty CSV decodes to empty set")
    func emptyStorageEmptySet() {
        let p = BookProgress(bookId: "book-a")
        #expect(p.completedCardIds.isEmpty)
    }
}
