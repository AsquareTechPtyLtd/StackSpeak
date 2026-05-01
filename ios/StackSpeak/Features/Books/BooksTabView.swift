import SwiftUI
import SwiftData

/// Books tab — replaces the old Library tab. Catalog of full-length books with
/// search, free/locked badges, and per-book progress when the user has opened a book.
struct BooksTabView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = BooksTabViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("books.navTitle")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $viewModel.query, prompt: "books.search.prompt")
                .task { await loadIfNeeded() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.loadError != nil {
            EmptyStateView(
                icon: "exclamationmark.triangle",
                title: "books.load.failed.title",
                message: "books.load.failed.message"
            )
            .background(theme.colors.bg)
        } else if viewModel.books.isEmpty {
            EmptyStateView(
                icon: "books.vertical",
                title: "books.empty.title",
                message: "books.empty.message"
            )
            .background(theme.colors.bg)
        } else if viewModel.filteredBooks.isEmpty {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "books.empty.noMatches.title",
                message: "books.empty.noMatches.message"
            )
            .background(theme.colors.bg)
        } else {
            bookList
        }
    }

    private var bookList: some View {
        List {
            Section {
                ForEach(viewModel.filteredBooks) { book in
                    NavigationLink {
                        BookDetailView(book: book)
                    } label: {
                        BookListRow(
                            book: book,
                            lockState: lockState(for: book),
                            currentStreak: viewModel.currentStreak(for: book.id),
                            completionRatio: viewModel.completionRatio(for: book)
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.colors.bg)
    }

    private func lockState(for book: BookSummary) -> BookLockState {
        guard let services, let progress = userProgress else {
            return book.freeForAll ? .free : .locked
        }
        return services.bookCatalog.lockState(for: book, userProgress: progress)
    }

    private func loadIfNeeded() async {
        guard let services else { return }
        await viewModel.load(catalogService: services.bookCatalog, modelContext: modelContext)
    }
}

#Preview("Books Tab — Light") {
    BooksTabView().withTheme(ThemeManager())
}

#Preview("Books Tab — Dark") {
    BooksTabView()
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
