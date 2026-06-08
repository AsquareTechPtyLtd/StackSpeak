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
    @State private var paywallBook: BookSummary?

    /// Persists category selection across view backgrounding (and navigation
    /// pushes/pops within the tab). Stored as a comma-joined string of raw IDs;
    /// resets on full app relaunch by virtue of `@SceneStorage`.
    @SceneStorage("books.selectedCategories") private var selectedCategoriesRaw: String = ""

    private var selectedCategoriesBinding: Binding<Set<BookCategory>> {
        Binding(
            get: {
                Set(selectedCategoriesRaw.split(separator: ",").compactMap {
                    BookCategory(rawValue: String($0))
                })
            },
            set: { newValue in
                let ids = newValue.sorted { $0.sortOrder < $1.sortOrder }.map(\.rawValue)
                selectedCategoriesRaw = ids.joined(separator: ",")
                viewModel.selectedCategories = newValue
            }
        )
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("books.navTitle")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $viewModel.query, prompt: "books.search.prompt")
                .task { await loadIfNeeded() }
                .onAppear {
                    // Hydrate the view model from persisted scene storage on first appear.
                    viewModel.selectedCategories = selectedCategoriesBinding.wrappedValue
                }
                .sheet(item: $paywallBook) { book in
                    BookLockedSheet(book: book)
                        .presentationDetents([.medium])
                }
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
        } else {
            VStack(spacing: 0) {
                CategoryFilterRow(selectedCategories: selectedCategoriesBinding)
                    .background(theme.colors.bg)
                if viewModel.filteredBooks.isEmpty {
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
        }
    }

    private var bookList: some View {
        List {
            Section {
                ForEach(viewModel.filteredBooks) { book in
                    let state = lockState(for: book)
                    if state == .locked {
                        Button {
                            paywallBook = book
                        } label: {
                            BookListRow(
                                book: book,
                                lockState: state,
                                currentStreak: viewModel.currentStreak(for: book.id),
                                completionRatio: viewModel.completionRatio(for: book)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink {
                            BookDetailView(book: book)
                        } label: {
                            BookListRow(
                                book: book,
                                lockState: state,
                                currentStreak: viewModel.currentStreak(for: book.id),
                                completionRatio: viewModel.completionRatio(for: book)
                            )
                        }
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
