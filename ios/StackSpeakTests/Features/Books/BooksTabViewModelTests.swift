import Testing
import Foundation
import SwiftData
@testable import StackSpeak

@Suite("BooksTabViewModel — search filter")
@MainActor
struct BooksTabViewModelFilterTests {

    private func book(
        id: String = UUID().uuidString,
        title: String = "Title",
        author: String? = "Author",
        summary: String = "Summary",
        tags: [String] = [],
        freeForAll: Bool = false
    ) -> BookSummary {
        BookSummary(
            id: id, title: title, author: author, summary: summary,
            coverIcon: "book", accentHex: nil, tags: tags,
            chapterCount: 1, cardCount: 5,
            manifestVersion: 1, manifestPath: "books/\(id)/manifest.json",
            freeForAll: freeForAll, sizeBytes: 1024
        )
    }

    @Test("Empty query returns all books unchanged")
    func emptyQueryReturnsAll() {
        let books = [book(title: "A"), book(title: "B"), book(title: "C")]
        #expect(BooksTabViewModel.filtered(books: books, query: "") == books)
    }

    @Test("Whitespace-only query treated as empty")
    func whitespaceOnlyQuery() {
        let books = [book(title: "A"), book(title: "B")]
        #expect(BooksTabViewModel.filtered(books: books, query: "   ").count == 2)
    }

    @Test("Title match is case-insensitive")
    func caseInsensitiveTitle() {
        let books = [book(title: "Generative AI Patterns"), book(title: "Foundations")]
        let result = BooksTabViewModel.filtered(books: books, query: "generative")
        #expect(result.count == 1)
        #expect(result.first?.title == "Generative AI Patterns")
    }

    @Test("Author match returns hits")
    func authorMatch() {
        let books = [
            book(title: "X", author: "Ada Lovelace"),
            book(title: "Y", author: "Turing")
        ]
        let result = BooksTabViewModel.filtered(books: books, query: "ada")
        #expect(result.map(\.title) == ["X"])
    }

    @Test("Summary substring matches")
    func summaryMatch() {
        let books = [
            book(title: "A", summary: "From LLMs to production agents."),
            book(title: "B", summary: "Strategy")
        ]
        let result = BooksTabViewModel.filtered(books: books, query: "agents")
        #expect(result.map(\.title) == ["A"])
    }

    @Test("Tag match works on any tag")
    func tagMatch() {
        let books = [
            book(title: "A", tags: ["agents", "production"]),
            book(title: "B", tags: ["frontend"])
        ]
        let result = BooksTabViewModel.filtered(books: books, query: "production")
        #expect(result.map(\.title) == ["A"])
    }

    @Test("Query is trimmed before matching")
    func queryIsTrimmed() {
        let books = [book(title: "Generative")]
        let result = BooksTabViewModel.filtered(books: books, query: "  generative  ")
        #expect(result.count == 1)
    }

    @Test("Nil author does not crash and is skipped during match")
    func nilAuthorSkipped() {
        let books = [
            book(title: "X", author: nil, summary: "no match"),
            book(title: "Y", author: "Ada", summary: "no match")
        ]
        let result = BooksTabViewModel.filtered(books: books, query: "ada")
        #expect(result.map(\.title) == ["Y"])
    }
}

@Suite("BooksTabViewModel — per-book metadata")
@MainActor
struct BooksTabViewModelMetadataTests {

    private func book(id: String, cardCount: Int = 100) -> BookSummary {
        BookSummary(
            id: id, title: id, author: nil, summary: "s",
            coverIcon: "book", accentHex: nil, tags: [],
            chapterCount: 1, cardCount: cardCount,
            manifestVersion: 1, manifestPath: "books/\(id)/manifest.json",
            freeForAll: false, sizeBytes: 0
        )
    }

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

    @Test("Books without progress show no streak and no completion ratio")
    func noProgressNoMetadata() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = BooksTabViewModel()
        vm.books = [book(id: "untouched")]
        vm.refreshProgress(modelContext: context)

        #expect(vm.currentStreak(for: "untouched") == nil)
        #expect(vm.completionRatio(for: vm.books[0]) == nil)
    }

    @Test("Book with progress surfaces currentStreakDays and ratio")
    func progressSurfaced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let progress = BookProgress(bookId: "opened")
        progress.recordReadDay(today: "2026-04-27", yesterday: "2026-04-26")
        progress.recordReadDay(today: "2026-04-28", yesterday: "2026-04-27")
        progress.markCardCompleted("c1")
        progress.markCardCompleted("c2")
        progress.markCardCompleted("c3")
        context.insert(progress)
        try context.save()

        let vm = BooksTabViewModel()
        vm.books = [book(id: "opened", cardCount: 10)]
        vm.refreshProgress(modelContext: context)

        #expect(vm.currentStreak(for: "opened") == 2)
        let ratio = try #require(vm.completionRatio(for: vm.books[0]))
        #expect(abs(ratio - 0.3) < 0.0001)
    }

    @Test("currentStreak is nil when streak is zero, even with progress row")
    func streakZeroSurfacesNil() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let progress = BookProgress(bookId: "opened")
        // No recordReadDay calls — streak stays at 0.
        context.insert(progress)
        try context.save()

        let vm = BooksTabViewModel()
        vm.books = [book(id: "opened")]
        vm.refreshProgress(modelContext: context)

        #expect(vm.currentStreak(for: "opened") == nil)
    }
}
