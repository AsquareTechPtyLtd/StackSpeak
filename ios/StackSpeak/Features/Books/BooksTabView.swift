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

/// Minimal locked-book gate shown when a non-pro user taps a pro book.
/// Replace with a full subscription flow when in-app purchase is wired up.
private struct BookLockedSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext

    let book: BookSummary

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: theme.spacing.lg) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(theme.colors.accent)

                VStack(spacing: theme.spacing.sm) {
                    Text("books.locked.title")
                        .font(TypographyTokens.title2)
                        .foregroundColor(theme.colors.ink)
                        .multilineTextAlignment(.center)

                    Text("books.locked.message")
                        .font(TypographyTokens.body)
                        .foregroundColor(theme.colors.inkMuted)
                        .multilineTextAlignment(.center)
                }

                PrimaryCTAButton("books.locked.cta") { dismiss() }

                devProToggle
            }
            .padding(theme.spacing.xl)

            Spacer()
        }
        .background(theme.colors.bg.ignoresSafeArea())
    }

    private var devProToggle: some View {
        HStack(spacing: theme.spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("books.dev.proToggle")
                    .font(TypographyTokens.footnote.weight(.medium))
                    .foregroundColor(theme.colors.inkMuted)
                Text("books.dev.proToggle.subtitle")
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkFaint)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { userProgress?.isProActive ?? false },
                set: { on in
                    guard let progress = userProgress else { return }
                    progress.isPro = on
                    progress.proExpiryDate = on
                        ? Calendar.current.date(byAdding: .year, value: 1, to: Date())
                        : nil
                    try? modelContext.save()
                    if on { dismiss() }
                }
            ))
            .labelsHidden()
        }
        .padding(theme.spacing.md)
        .background(theme.colors.surfaceAlt)
        .clipShape(.rect(cornerRadius: RadiusTokens.inline))
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
