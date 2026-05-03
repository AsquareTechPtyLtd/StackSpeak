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
        categories: [BookCategory] = [.codeCraft],
        freeForAll: Bool = false
    ) -> BookSummary {
        BookSummary(
            id: id, title: title, author: author, summary: summary,
            coverIcon: "book", accentHex: nil, tags: tags,
            categories: categories,
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

@Suite("BooksTabViewModel — category filter")
@MainActor
struct BooksTabViewModelCategoryFilterTests {

    private func book(
        title: String,
        categories: [BookCategory]
    ) -> BookSummary {
        BookSummary(
            id: title, title: title, author: nil, summary: "s",
            coverIcon: "book", accentHex: nil, tags: [],
            categories: categories,
            chapterCount: 1, cardCount: 1,
            manifestVersion: 1, manifestPath: "books/\(title)/manifest.json",
            freeForAll: false, sizeBytes: 0
        )
    }

    @Test("Empty category set returns all books unchanged")
    func emptyCategoriesReturnsAll() {
        let books = [
            book(title: "A", categories: [.aiML]),
            book(title: "B", categories: [.codeCraft])
        ]
        let result = BooksTabViewModel.filtered(books: books, query: "", categories: [])
        #expect(result.map(\.title) == ["A", "B"])
    }

    @Test("Single category filter narrows to matching books")
    func singleCategory() {
        let books = [
            book(title: "Refactor", categories: [.codeCraft]),
            book(title: "Agents", categories: [.aiML]),
            book(title: "Test", categories: [.testing])
        ]
        let result = BooksTabViewModel.filtered(
            books: books, query: "", categories: [.aiML]
        )
        #expect(result.map(\.title) == ["Agents"])
    }

    @Test("Multi-category filter uses OR semantics — union, not intersection")
    func multiCategoryOR() {
        let books = [
            book(title: "Refactor", categories: [.codeCraft]),
            book(title: "Agents", categories: [.aiML]),
            book(title: "Test", categories: [.testing]),
            book(title: "Cloud", categories: [.cloud])
        ]
        let result = BooksTabViewModel.filtered(
            books: books, query: "", categories: [.aiML, .testing]
        )
        #expect(Set(result.map(\.title)) == Set(["Agents", "Test"]))
    }

    @Test("Books with multiple categories appear once when several matching categories are selected")
    func multiCategoryBookDeduped() {
        let books = [
            book(title: "AI Refactor", categories: [.codeCraft, .aiML])
        ]
        let result = BooksTabViewModel.filtered(
            books: books, query: "", categories: [.codeCraft, .aiML]
        )
        #expect(result.count == 1)
        #expect(result.first?.title == "AI Refactor")
    }

    @Test("Category filter combines with text query — both must match")
    func combinedWithQuery() {
        let books = [
            book(title: "Agents", categories: [.aiML]),
            book(title: "Refactor with AI", categories: [.codeCraft]),
            book(title: "Pure Refactor", categories: [.codeCraft])
        ]
        // query="refactor" + category=codeCraft → both code-craft books match
        let result = BooksTabViewModel.filtered(
            books: books, query: "refactor", categories: [.codeCraft]
        )
        #expect(Set(result.map(\.title)) == Set(["Refactor with AI", "Pure Refactor"]))
    }

    @Test("Empty filter and empty query returns full list")
    func bothEmpty() {
        let books = [
            book(title: "A", categories: [.aiML]),
            book(title: "B", categories: [.codeCraft])
        ]
        let result = BooksTabViewModel.filtered(books: books, query: "", categories: [])
        #expect(result.count == 2)
    }

    @Test("isFiltered tracks whether any filter is narrowing the catalog")
    func isFilteredFlag() {
        let viewModel = BooksTabViewModel()
        #expect(viewModel.isFiltered == false)

        viewModel.query = "x"
        #expect(viewModel.isFiltered == true)

        viewModel.query = ""
        viewModel.selectedCategories = [.aiML]
        #expect(viewModel.isFiltered == true)

        viewModel.selectedCategories = []
        #expect(viewModel.isFiltered == false)
    }

    @Test("bookCount returns total when category is nil and per-category counts otherwise")
    func bookCountInCategory() {
        let viewModel = BooksTabViewModel()
        viewModel.books = [
            book(title: "A", categories: [.aiML]),
            book(title: "B", categories: [.aiML, .codeCraft]),
            book(title: "C", categories: [.testing])
        ]
        #expect(viewModel.bookCount(in: nil) == 3)
        #expect(viewModel.bookCount(in: .aiML) == 2)
        #expect(viewModel.bookCount(in: .codeCraft) == 1)
        #expect(viewModel.bookCount(in: .cloud) == 0)
    }
}

@Suite("BookCategory — taxonomy & decoding")
struct BookCategoryTests {

    @Test("All 7 locked category IDs are present and stable")
    func taxonomyIds() {
        let ids = Set(BookCategory.allCases.map(\.rawValue))
        #expect(ids == Set([
            "ai-ml", "architecture", "code-craft", "cloud", "data", "testing", "people"
        ]))
    }

    @Test("init(id:) round-trips for valid IDs and returns nil for unknowns")
    func initFromId() {
        for category in BookCategory.allCases {
            #expect(BookCategory(id: category.rawValue) == category)
        }
        #expect(BookCategory(id: "frontend") == nil)
        #expect(BookCategory(id: "") == nil)
    }

    @Test("sortOrder is a total ordering across all 7 categories")
    func sortOrderIsTotal() {
        let orders = BookCategory.allCases.map(\.sortOrder)
        #expect(Set(orders).count == BookCategory.allCases.count)
        #expect(orders == orders.sorted())
    }

    @Test("Each category has a non-empty SF Symbol icon and accent hex")
    func iconAndAccentNonEmpty() {
        for category in BookCategory.allCases {
            #expect(!category.icon.isEmpty)
            #expect(category.accentHex.hasPrefix("#"))
            #expect(category.accentHex.count == 7)  // #RRGGBB
        }
    }

    @Test("Codable round-trip via raw string ID")
    func codableRoundTrip() throws {
        let categories: [BookCategory] = [.aiML, .codeCraft, .testing]
        let data = try JSONEncoder().encode(categories)
        let restored = try JSONDecoder().decode([BookCategory].self, from: data)
        #expect(restored == categories)

        // Decode from a raw JSON array of strings (matches what build-books emits).
        let rawJSON = #"["data", "people"]"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([BookCategory].self, from: rawJSON)
        #expect(decoded == [.data, .people])
    }
}

@Suite("BooksTabViewModel — per-book metadata")
@MainActor
struct BooksTabViewModelMetadataTests {

    private func book(id: String, cardCount: Int = 100) -> BookSummary {
        BookSummary(
            id: id, title: id, author: nil, summary: "s",
            coverIcon: "book", accentHex: nil, tags: [],
            categories: [.codeCraft],
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
