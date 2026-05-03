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

    /// Active category filter. Empty set = "All" (no filter). OR-semantics — a book
    /// matches if any of its categories is in `selectedCategories`. Persisted across
    /// view backgrounding by the view (`@SceneStorage`); resets on full app launch.
    var selectedCategories: Set<BookCategory> = []

    /// `bookId → progress` so per-row metadata is O(1).
    private(set) var progressByBookId: [String: BookProgress] = [:]

    /// Result of the combined search + category filter applied to the current `books` list.
    var filteredBooks: [BookSummary] {
        Self.filtered(books: books, query: query, categories: selectedCategories)
    }

    /// True if any filtering is currently narrowing the catalog. The view uses this
    /// to choose between "*N* books" vs "*N* of *M* books" rendering.
    var isFiltered: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !selectedCategories.isEmpty
    }

    /// Number of books in `books` that carry the given category. Used by the chip
    /// row to show a per-category count badge. `nil` argument returns the total.
    func bookCount(in category: BookCategory?) -> Int {
        guard let category else { return books.count }
        return books.filter { $0.categories.contains(category) }.count
    }

    /// Pure filter — text query (case-insensitive substring across title, author,
    /// summary, and tags) AND category filter (OR semantics across `categories`).
    /// Whitespace-trimmed query; empty query means "no text filter". Empty
    /// `categories` means "no category filter". Both empty = all books.
    static func filtered(
        books: [BookSummary],
        query: String,
        categories: Set<BookCategory> = []
    ) -> [BookSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return books.filter { book in
            let matchesQuery = trimmed.isEmpty
                || book.title.lowercased().contains(trimmed)
                || (book.author?.lowercased().contains(trimmed) ?? false)
                || book.summary.lowercased().contains(trimmed)
                || book.tags.contains(where: { $0.lowercased().contains(trimmed) })
            let matchesCategory = categories.isEmpty
                || book.categories.contains(where: { categories.contains($0) })
            return matchesQuery && matchesCategory
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
