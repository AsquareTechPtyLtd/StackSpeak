import Foundation
import SwiftData

/// View state for the Books tab catalog list. Drives:
///   - the search field (`query`)
///   - per-book lock badges (free / locked / unlocked)
///   - per-book streak + completion ratio when the user has opened the book
///
/// Keeps the search filter as a static pure function so it's testable without
/// constructing a full ViewModel.
@MainActor
@Observable
final class BooksTabViewModel {
    var query: String = ""
    var books: [BookSummary] = []
    var loadError: (any Error)?

    /// `bookId → progress` so per-row metadata is O(1).
    private(set) var progressByBookId: [String: BookProgress] = [:]

    /// Result of the search filter applied to the current `books` list.
    var filteredBooks: [BookSummary] {
        Self.filtered(books: books, query: query)
    }

    /// Pure search filter — case-insensitive substring match across title,
    /// author, summary, and any tag. Whitespace-trimmed. Empty query → all books.
    static func filtered(books: [BookSummary], query: String) -> [BookSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return books }
        return books.filter { book in
            book.title.lowercased().contains(trimmed)
                || (book.author?.lowercased().contains(trimmed) ?? false)
                || book.summary.lowercased().contains(trimmed)
                || book.tags.contains(where: { $0.lowercased().contains(trimmed) })
        }
    }

    /// Returns the per-book streak day count if the user has read this book before; `nil` otherwise.
    func currentStreak(for bookId: String) -> Int? {
        guard let progress = progressByBookId[bookId] else { return nil }
        return progress.currentStreakDays > 0 ? progress.currentStreakDays : nil
    }

    /// Returns 0...1 if the user has touched this book and its catalog entry has cards;
    /// `nil` otherwise. Empty/zero-card books also return `nil` (no rendering of "0 / 0").
    func completionRatio(for book: BookSummary) -> Double? {
        guard let progress = progressByBookId[book.id] else { return nil }
        guard book.cardCount > 0 else { return nil }
        return Double(progress.completedCardIds.count) / Double(book.cardCount)
    }

    /// Loads the catalog from the service and refreshes per-book progress from SwiftData.
    func load(catalogService: BookCatalogService, modelContext: ModelContext) async {
        do {
            let catalog = try await catalogService.loadCatalog()
            self.books = catalog.books
            self.loadError = nil
        } catch {
            self.books = []
            self.loadError = error
        }
        let descriptor = FetchDescriptor<BookProgress>()
        let progresses = (try? modelContext.fetch(descriptor)) ?? []
        self.progressByBookId = Dictionary(uniqueKeysWithValues: progresses.map { ($0.bookId, $0) })
    }

    /// Updates `progressByBookId` after a card flow session ends or a book is opened.
    func refreshProgress(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<BookProgress>()
        let progresses = (try? modelContext.fetch(descriptor)) ?? []
        self.progressByBookId = Dictionary(uniqueKeysWithValues: progresses.map { ($0.bookId, $0) })
    }
}
