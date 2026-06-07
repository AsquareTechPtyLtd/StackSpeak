import Foundation
import SwiftData

/// Owns the lifecycle of `BookmarkedCard` rows. Card bookmarks live in their own
/// SwiftData model (separate from word bookmarks under `UserProgress`) because
/// the keys are `String` (card IDs) rather than `UUID`, and the surface needs
/// `bookId` + `chapterId` for deep-linking from the You tab.
@MainActor
protocol BookmarkRepository {
    func toggle(card: BookCard, in bookId: String, chapterId: String) throws -> Bool
    func isBookmarked(cardId: String) throws -> Bool
    func allBookmarks() throws -> [BookmarkedCard]
    func remove(cardId: String) throws
}

@MainActor
final class BookmarkService: BookmarkRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Adds the card to bookmarks if absent, removes it if present. Returns the
    /// new state — `true` if bookmarked after the call, `false` if removed.
    /// Idempotent on rapid double-toggle (the SwiftData unique constraint guards us).
    @discardableResult
    func toggle(card: BookCard, in bookId: String, chapterId: String) throws -> Bool {
        if let existing = try fetch(cardId: card.id) {
            modelContext.delete(existing)
            try modelContext.save()
            return false
        }
        let bookmark = BookmarkedCard(cardId: card.id, bookId: bookId, chapterId: chapterId)
        modelContext.insert(bookmark)
        try modelContext.save()
        return true
    }

    func isBookmarked(cardId: String) throws -> Bool {
        try fetch(cardId: cardId) != nil
    }

    func allBookmarks() throws -> [BookmarkedCard] {
        let descriptor = FetchDescriptor<BookmarkedCard>(
            sortBy: [SortDescriptor(\.bookmarkedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func remove(cardId: String) throws {
        guard let row = try fetch(cardId: cardId) else { return }
        modelContext.delete(row)
        try modelContext.save()
    }

    private func fetch(cardId: String) throws -> BookmarkedCard? {
        let descriptor = FetchDescriptor<BookmarkedCard>(
            predicate: #Predicate { $0.cardId == cardId }
        )
        return try modelContext.fetch(descriptor).first
    }
}
