import Testing
import Foundation
import SwiftData
@testable import StackSpeak

@Suite("BookmarkService — toggle, list, remove")
@MainActor
struct BookmarkServiceTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            BookProgress.self, BookmarkedCard.self,
            UserProgress.self, DailySet.self,
            Word.self, PracticedSentence.self,
            ReviewState.self, AssessmentResult.self, WordReport.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    private func card(_ id: String) -> BookCard {
        BookCard(id: id, order: 1, title: "T", teaser: "x", explanation: [], feynman: [])
    }

    @Test("Toggle adds when absent, removes when present")
    func toggleAddRemove() throws {
        let ctx = try makeContext()
        let service = BookmarkService(modelContext: ctx)
        #expect(try service.isBookmarked(cardId: "c1") == false)
        let added = try service.toggle(card: card("c1"), in: "book", chapterId: "ch1")
        #expect(added == true)
        #expect(try service.isBookmarked(cardId: "c1") == true)
        let removed = try service.toggle(card: card("c1"), in: "book", chapterId: "ch1")
        #expect(removed == false)
        #expect(try service.isBookmarked(cardId: "c1") == false)
    }

    @Test("Rapid double-toggle ends in expected state — no duplicates created")
    func idempotencyOnDoubleToggle() throws {
        let ctx = try makeContext()
        let service = BookmarkService(modelContext: ctx)
        try service.toggle(card: card("c1"), in: "book", chapterId: "ch1")
        try service.toggle(card: card("c1"), in: "book", chapterId: "ch1")
        try service.toggle(card: card("c1"), in: "book", chapterId: "ch1")
        #expect(try service.isBookmarked(cardId: "c1") == true)
        #expect(try service.allBookmarks().count == 1)
    }

    @Test("allBookmarks returns most-recent first")
    func sortedByDate() async throws {
        let ctx = try makeContext()
        let service = BookmarkService(modelContext: ctx)
        try service.toggle(card: card("c1"), in: "book", chapterId: "ch1")
        try await Task.sleep(nanoseconds: 10_000_000)
        try service.toggle(card: card("c2"), in: "book", chapterId: "ch1")
        try await Task.sleep(nanoseconds: 10_000_000)
        try service.toggle(card: card("c3"), in: "book", chapterId: "ch2")

        let bookmarks = try service.allBookmarks()
        #expect(bookmarks.map(\.cardId) == ["c3", "c2", "c1"])
    }

    @Test("remove(cardId:) deletes the bookmark")
    func explicitRemove() throws {
        let ctx = try makeContext()
        let service = BookmarkService(modelContext: ctx)
        try service.toggle(card: card("c1"), in: "book", chapterId: "ch1")
        try service.toggle(card: card("c2"), in: "book", chapterId: "ch1")
        try service.remove(cardId: "c1")
        #expect(try service.isBookmarked(cardId: "c1") == false)
        #expect(try service.isBookmarked(cardId: "c2") == true)
    }
}
