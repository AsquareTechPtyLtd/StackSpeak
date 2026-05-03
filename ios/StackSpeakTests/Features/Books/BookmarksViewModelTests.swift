import Testing
import Foundation
import SwiftData
@testable import StackSpeak

/// In-memory `BookmarkRepository` so the BookmarksViewModel tests don't need
/// a SwiftData container for the bookmark surface.
@MainActor
final class InMemoryBookmarkRepository: BookmarkRepository {
    private var rows: [BookmarkedCard] = []

    func toggle(card: BookCard, in bookId: String, chapterId: String) -> Bool {
        if let idx = rows.firstIndex(where: { $0.cardId == card.id }) {
            rows.remove(at: idx)
            return false
        }
        rows.append(BookmarkedCard(cardId: card.id, bookId: bookId, chapterId: chapterId))
        return true
    }

    func isBookmarked(cardId: String) -> Bool {
        rows.contains(where: { $0.cardId == cardId })
    }

    func allBookmarks() -> [BookmarkedCard] {
        rows.sorted { $0.bookmarkedAt > $1.bookmarkedAt }
    }

    func remove(cardId: String) {
        rows.removeAll { $0.cardId == cardId }
    }
}

@Suite("BookmarksViewModel — surfaces both card and word bookmarks")
@MainActor
struct BookmarksViewModelTests {

    private func sampleCatalog() -> BooksCatalog {
        BooksCatalog(
            version: 1,
            updatedAt: Date(),
            books: [
                BookSummary(
                    id: "book-1", title: "Book One", author: nil, summary: "s",
                    coverIcon: "book", accentHex: nil, tags: [],
                    categories: [.codeCraft],
                    chapterCount: 1, cardCount: 2, manifestVersion: 1,
                    manifestPath: "books/book-1/manifest.json",
                    freeForAll: true, sizeBytes: 0
                )
            ]
        )
    }

    private func sampleManifest() -> BookManifest {
        BookManifest(
            id: "book-1", version: 1, title: "Book One", author: nil,
            summary: "summary",
            categories: [.codeCraft],
            chapters: [
                ChapterSummary(
                    id: "ch1", order: 1, title: "Ch1", summary: "",
                    icon: "book", cardCount: 2, cardIds: ["c1", "c2"],
                    shards: ["chapters/ch1.json"]
                )
            ]
        )
    }

    private func sampleCards() -> [BookCard] {
        [
            BookCard(id: "c1", order: 1, title: "First Card", teaser: "t1", explanation: [], feynman: []),
            BookCard(id: "c2", order: 2, title: "Second Card", teaser: "t2", explanation: [], feynman: [])
        ]
    }

    @Test("Empty repository + empty word bookmarks → no rows, hasAny=false")
    func empty() async {
        let repo = InMemoryBookmarkRepository()
        let mock = MockBookContentSource(catalog: sampleCatalog())
        mock.manifests["book-1"] = sampleManifest()
        mock.shards["book-1/ch1"] = sampleCards()

        let vm = BookmarksViewModel()
        await vm.load(
            userProgress: UserProgress(),
            catalogService: BookCatalogService(source: mock),
            contentSource: mock,
            bookmarkRepository: repo
        )
        #expect(vm.cardRows.isEmpty)
        #expect(vm.wordIds.isEmpty)
        #expect(vm.hasAnyBookmarks == false)
    }

    @Test("Resolves card titles from the content source and book titles from catalog")
    func resolvesTitles() async {
        let repo = InMemoryBookmarkRepository()
        let mock = MockBookContentSource(catalog: sampleCatalog())
        mock.manifests["book-1"] = sampleManifest()
        mock.shards["book-1/ch1"] = sampleCards()

        _ = repo.toggle(card: sampleCards()[0], in: "book-1", chapterId: "ch1")
        _ = repo.toggle(card: sampleCards()[1], in: "book-1", chapterId: "ch1")

        let vm = BookmarksViewModel()
        await vm.load(
            userProgress: UserProgress(),
            catalogService: BookCatalogService(source: mock),
            contentSource: mock,
            bookmarkRepository: repo
        )
        #expect(vm.cardRows.count == 2)
        let titles = vm.cardRows.map(\.cardTitle).sorted()
        #expect(titles == ["First Card", "Second Card"])
        #expect(vm.cardRows.allSatisfy { $0.bookTitle == "Book One" })
        #expect(vm.hasAnyBookmarks == true)
    }

    @Test("Word bookmarks surface alongside card bookmarks")
    func wordBookmarksSurface() async {
        let repo = InMemoryBookmarkRepository()
        let mock = MockBookContentSource(catalog: sampleCatalog())
        mock.manifests["book-1"] = sampleManifest()
        mock.shards["book-1/ch1"] = sampleCards()
        _ = repo.toggle(card: sampleCards()[0], in: "book-1", chapterId: "ch1")

        let user = UserProgress()
        let id = UUID()
        user.bookmarkedWordIds = [id]

        let vm = BookmarksViewModel()
        await vm.load(
            userProgress: user,
            catalogService: BookCatalogService(source: mock),
            contentSource: mock,
            bookmarkRepository: repo
        )
        #expect(vm.cardRows.count == 1)
        #expect(vm.wordIds == [id])
        #expect(vm.hasAnyBookmarks == true)
    }

    @Test("Falls back to IDs when catalog/content lookup fails")
    func fallbackOnMissingContent() async {
        let repo = InMemoryBookmarkRepository()
        // Empty catalog + no manifest, but user has an existing card bookmark
        // (e.g. content version mismatch / catalog not loaded).
        let mock = MockBookContentSource(catalog: BooksCatalog(version: 1, updatedAt: Date(), books: []))
        let card = BookCard(id: "lone-card", order: 1, title: "Original", teaser: "", explanation: [], feynman: [])
        _ = repo.toggle(card: card, in: "missing-book", chapterId: "missing-chapter")

        let vm = BookmarksViewModel()
        await vm.load(
            userProgress: UserProgress(),
            catalogService: BookCatalogService(source: mock),
            contentSource: mock,
            bookmarkRepository: repo
        )
        #expect(vm.cardRows.count == 1)
        let row = try! #require(vm.cardRows.first)
        #expect(row.bookTitle == "missing-book")
        #expect(row.cardTitle == "lone-card")
    }
}
