import Testing
import Foundation
import SwiftData
@testable import StackSpeak

@Suite("BookDetailViewModel — chapter ordering + completion")
@MainActor
struct BookDetailViewModelChapterTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            BookProgress.self, BookmarkedCard.self,
            UserProgress.self, DailySet.self,
            Word.self, PracticedSentence.self,
            ReviewState.self, AssessmentResult.self, WordReport.self
        ])
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }

    private func chapter(_ id: String, order: Int, cardIds: [String]) -> ChapterSummary {
        ChapterSummary(
            id: id, order: order, title: id, summary: "",
            icon: "book", cardCount: cardIds.count, cardIds: cardIds,
            shards: ["chapters/\(id).json"]
        )
    }

    private func manifest(_ chapters: [ChapterSummary]) -> BookManifest {
        BookManifest(
            id: "book-1", version: 1, title: "Book", author: nil,
            summary: "summary", categories: [.codeCraft], chapters: chapters
        )
    }

    @Test("orderedChapters sorts by `order` regardless of input shuffle")
    func chaptersAreOrdered() async throws {
        let mock = MockBookContentSource()
        mock.manifests["book-1"] = manifest([
            chapter("c", order: 3, cardIds: ["x"]),
            chapter("a", order: 1, cardIds: ["y"]),
            chapter("b", order: 2, cardIds: ["z"])
        ])

        let container = try makeContainer()
        let vm = BookDetailViewModel()
        await vm.open(
            bookId: "book-1",
            catalogService: BookCatalogService(source: mock),
            contentSource: mock,
            modelContext: ModelContext(container)
        )
        #expect(vm.orderedChapters.map(\.id) == ["a", "b", "c"])
    }

    @Test("Per-chapter completion is intersection of completed ∩ chapter.cardIds")
    func completionIsIntersection() async throws {
        let mock = MockBookContentSource()
        mock.manifests["book-1"] = manifest([
            chapter("ch1", order: 1, cardIds: ["a", "b", "c", "d"]),
            chapter("ch2", order: 2, cardIds: ["e", "f"])
        ])

        let container = try makeContainer()
        let context = ModelContext(container)
        let progress = BookProgress(bookId: "book-1")
        progress.markCardCompleted("a")
        progress.markCardCompleted("b")
        progress.markCardCompleted("e")
        // 'z' is not in either chapter — should not contribute to either ratio.
        progress.markCardCompleted("z")
        context.insert(progress)
        try context.save()

        let vm = BookDetailViewModel()
        await vm.open(
            bookId: "book-1",
            catalogService: BookCatalogService(source: mock),
            contentSource: mock,
            modelContext: context
        )
        let chapters = vm.orderedChapters
        #expect(vm.completedCount(for: chapters[0]) == 2)
        #expect(abs(vm.completionRatio(for: chapters[0]) - 0.5) < 0.0001)
        #expect(vm.completedCount(for: chapters[1]) == 1)
        #expect(abs(vm.completionRatio(for: chapters[1]) - 0.5) < 0.0001)
    }
}

@Suite("BookDetailViewModel — streak toast on open")
@MainActor
struct BookDetailViewModelStreakToastTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            BookProgress.self, BookmarkedCard.self,
            UserProgress.self, DailySet.self,
            Word.self, PracticedSentence.self,
            ReviewState.self, AssessmentResult.self, WordReport.self
        ])
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }

    private func manifest() -> BookManifest {
        BookManifest(
            id: "book-1", version: 1, title: "Book", author: nil,
            summary: "summary",
            categories: [.codeCraft],
            chapters: [
                ChapterSummary(
                    id: "ch1", order: 1, title: "Ch1", summary: "",
                    icon: "book", cardCount: 1, cardIds: ["a"],
                    shards: ["chapters/ch1.json"]
                )
            ]
        )
    }

    @Test("Toast emits when currentStreakDays >= 2")
    func emitsToastForActiveStreak() async throws {
        let mock = MockBookContentSource()
        mock.manifests["book-1"] = manifest()

        let container = try makeContainer()
        let context = ModelContext(container)
        let progress = BookProgress(bookId: "book-1")
        progress.recordReadDay(today: "2026-04-26", yesterday: "2026-04-25")
        progress.recordReadDay(today: "2026-04-27", yesterday: "2026-04-26")
        context.insert(progress)
        try context.save()

        let vm = BookDetailViewModel()
        await vm.open(
            bookId: "book-1",
            catalogService: BookCatalogService(source: mock),
            contentSource: mock,
            modelContext: context
        )
        #expect(vm.consumeStreakToast() == 2)
    }

    @Test("Toast suppressed when streak <= 1")
    func suppressedForShortStreak() async throws {
        let mock = MockBookContentSource()
        mock.manifests["book-1"] = manifest()

        let container = try makeContainer()
        let context = ModelContext(container)
        let progress = BookProgress(bookId: "book-1")
        progress.recordReadDay(today: "2026-04-27", yesterday: "2026-04-26")
        context.insert(progress)
        try context.save()

        let vm = BookDetailViewModel()
        await vm.open(
            bookId: "book-1",
            catalogService: BookCatalogService(source: mock),
            contentSource: mock,
            modelContext: context
        )
        #expect(vm.consumeStreakToast() == nil)
    }

    @Test("Same-session re-open does not re-emit the toast")
    func toastEmitsOncePerSession() async throws {
        let mock = MockBookContentSource()
        mock.manifests["book-1"] = manifest()

        let container = try makeContainer()
        let context = ModelContext(container)
        let progress = BookProgress(bookId: "book-1")
        progress.recordReadDay(today: "2026-04-26", yesterday: "2026-04-25")
        progress.recordReadDay(today: "2026-04-27", yesterday: "2026-04-26")
        context.insert(progress)
        try context.save()

        let vm = BookDetailViewModel()
        await vm.open(
            bookId: "book-1",
            catalogService: BookCatalogService(source: mock),
            contentSource: mock,
            modelContext: context
        )
        _ = vm.consumeStreakToast()  // consume the first emission

        // Re-call open within the same VM instance — should not emit again.
        await vm.open(
            bookId: "book-1",
            catalogService: BookCatalogService(source: mock),
            contentSource: mock,
            modelContext: context
        )
        #expect(vm.consumeStreakToast() == nil)
    }
}
