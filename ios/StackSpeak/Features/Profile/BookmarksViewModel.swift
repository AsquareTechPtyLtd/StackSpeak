import Foundation
import SwiftData

/// View state for the consolidated bookmarks screen under the You tab.
/// Surfaces two sections: bookmarked book cards and bookmarked words.
@MainActor
@Observable
final class BookmarksViewModel {
    /// Display row for a bookmarked card. Wraps `BookmarkedCard` with the
    /// resolved book title and card title (looked up at load time so the row
    /// renders without re-fetching).
    struct CardRow: Identifiable, Equatable {
        let id: String           // cardId
        let bookId: String
        let chapterId: String
        let bookTitle: String
        let cardTitle: String
    }

    private(set) var cardRows: [CardRow] = []
    private(set) var wordIds: Set<UUID> = []

    var hasAnyBookmarks: Bool { !cardRows.isEmpty || !wordIds.isEmpty }

    /// Loads both bookmark surfaces. Card rows resolve their book + card titles
    /// from the catalog (book) and content source (card) — best-effort: a row
    /// whose book or card is missing falls back to the IDs.
    func load(
        userProgress: UserProgress?,
        catalogService: BookCatalogService,
        contentSource: any BookContentSource,
        bookmarkRepository: any BookmarkRepository
    ) async {
        wordIds = userProgress?.bookmarkedWordIds ?? []

        let bookmarks = bookmarkRepository.allBookmarks()
        guard !bookmarks.isEmpty else {
            cardRows = []
            return
        }

        // Resolve book titles via the catalog.
        let catalog = (try? await catalogService.loadCatalog())?.books ?? []
        let titlesByBookId = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0.title) })

        // Group card lookups by (bookId, chapterId) so we only load each chapter once.
        var resolved: [CardRow] = []
        let grouped = Dictionary(grouping: bookmarks, by: { Pair($0.bookId, $0.chapterId) })

        for (key, items) in grouped {
            let cards = await loadCardsBestEffort(
                bookId: key.first,
                chapterId: key.second,
                contentSource: contentSource
            )
            let cardsById = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
            for bookmark in items {
                let bookTitle = titlesByBookId[bookmark.bookId] ?? bookmark.bookId
                let cardTitle = cardsById[bookmark.cardId]?.title ?? bookmark.cardId
                resolved.append(CardRow(
                    id: bookmark.cardId,
                    bookId: bookmark.bookId,
                    chapterId: bookmark.chapterId,
                    bookTitle: bookTitle,
                    cardTitle: cardTitle
                ))
            }
        }

        // Latest first.
        cardRows = resolved.sorted { $0.cardTitle < $1.cardTitle }
    }

    private func loadCardsBestEffort(
        bookId: String,
        chapterId: String,
        contentSource: any BookContentSource
    ) async -> [BookCard] {
        guard let manifest = try? await contentSource.loadManifest(bookId: bookId) else { return [] }
        guard let chapter = manifest.chapters.first(where: { $0.id == chapterId }) else { return [] }
        return (try? await contentSource.loadChapter(
            bookId: bookId,
            chapterId: chapterId,
            shards: chapter.shards
        )) ?? []
    }
}

private struct Pair: Hashable {
    let first: String
    let second: String
    init(_ first: String, _ second: String) {
        self.first = first
        self.second = second
    }
}
