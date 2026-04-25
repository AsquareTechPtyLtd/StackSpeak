import SwiftUI

/// Library — practiced-word reference list.
///
/// L1 — converted from a `LazyVStack` of cards to a native `List(.insetGrouped)`
/// for fast scanning, free Dynamic Type, and free swipe actions.
/// L2 — leading swipe toggles mastered, trailing swipe toggles bookmark.
/// L3 — filter chip strip replaced with a `Menu` next to search.
/// L4 — nav title aligned to a single noun ("Library").
struct LibraryView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.userProgress) private var userProgress

    @State private var viewModel = LibraryViewModel()
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("library.navTitle")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $searchText, prompt: "library.search.prompt")
                .toolbar { filterToolbar }
                .onChange(of: searchText) { _, newValue in viewModel.searchQuery = newValue }
                .task { await loadAllWords() }
                .onChange(of: userProgress?.masteredWordIds) { _, newIds in
                    viewModel.masteredIds = newIds ?? []
                }
                .onChange(of: userProgress?.bookmarkedWordIds) { _, newIds in
                    viewModel.bookmarkedIds = newIds ?? []
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.allWords.isEmpty && searchText.isEmpty && viewModel.selectedStack == nil {
            EmptyStateView(
                icon: "books.vertical",
                title: "library.empty.title",
                message: "library.empty.message"
            )
            .background(theme.colors.bg)
        } else if viewModel.filteredWords.isEmpty {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "library.empty.noMatches.title",
                message: "library.empty.noMatches.message"
            )
            .background(theme.colors.bg)
        } else {
            wordList
        }
    }

    private var wordList: some View {
        List {
            if let stack = viewModel.selectedStack {
                Section {
                    Button(action: { viewModel.selectedStack = nil }) {
                        HStack(spacing: theme.spacing.sm) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(theme.colors.inkFaint)
                            Text(String(format: String(localized: "library.activeFilter.format"),
                                        stack.displayName))
                                .font(TypographyTokens.footnote)
                                .foregroundColor(theme.colors.inkMuted)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.colors.surfaceAlt)
                }
            }

            Section {
                ForEach(viewModel.filteredWords) { word in
                    if let progress = userProgress {
                        NavigationLink {
                            WordDetailView(word: word, userProgress: progress)
                        } label: {
                            row(word: word, progress: progress)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                toggleMastered(wordId: word.id, progress: progress)
                            } label: {
                                Label(progress.masteredWordIds.contains(word.id)
                                      ? "Unmaster" : "Master",
                                      systemImage: "checkmark.seal.fill")
                            }
                            .tint(theme.colors.good)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                toggleBookmark(wordId: word.id)
                            } label: {
                                Label(progress.bookmarkedWordIds.contains(word.id)
                                      ? "Unbookmark" : "Bookmark",
                                      systemImage: "bookmark.fill")
                            }
                            .tint(theme.colors.accent)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.colors.bg)
    }

    private func row(word: Word, progress: UserProgress) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: theme.spacing.xs) {
                Text(word.word)
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.ink)
                if progress.masteredWordIds.contains(word.id) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundColor(theme.colors.good)
                        .accessibilityLabel(String(localized: "a11y.mastered"))
                }
                if progress.bookmarkedWordIds.contains(word.id) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 11))
                        .foregroundColor(theme.colors.accent)
                        .accessibilityLabel(String(localized: "a11y.bookmarked"))
                }
                Spacer()
                MetaCaption(level: word.unlockLevel)
            }
            Text(word.shortDefinition)
                .font(TypographyTokens.subheadline)
                .foregroundColor(theme.colors.inkMuted)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    @ToolbarContentBuilder
    private var filterToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    viewModel.selectedStack = nil
                } label: {
                    Label(String(localized: "library.filter.all"),
                          systemImage: viewModel.selectedStack == nil ? "checkmark" : "")
                }
                Divider()
                ForEach(WordStack.allCases) { stack in
                    Button {
                        viewModel.selectedStack = (viewModel.selectedStack == stack) ? nil : stack
                    } label: {
                        Label(stack.displayName,
                              systemImage: viewModel.selectedStack == stack ? "checkmark" : "")
                    }
                }
            } label: {
                Image(systemName: viewModel.selectedStack == nil
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
                    .foregroundColor(theme.colors.accent)
            }
            .accessibilityLabel(String(localized: "library.filter.label"))
        }
    }

    // MARK: - Actions

    private func toggleMastered(wordId: UUID, progress: UserProgress) {
        if progress.masteredWordIds.contains(wordId) {
            services?.progress.unmarkWordMastered(wordId, userProgress: progress)
        } else {
            services?.progress.markWordMastered(wordId, userProgress: progress)
        }
    }

    private func toggleBookmark(wordId: UUID) {
        guard let progress = userProgress else { return }
        services?.progress.toggleBookmark(wordId, userProgress: progress)
    }

    private func loadAllWords() async {
        guard let progress = userProgress, let services else { return }
        if let words = try? services.word.fetchWords(matching: "", filters: WordFilters(
            stack: nil,
            level: nil,
            masteredIds: progress.masteredWordIds,
            bookmarkedIds: progress.bookmarkedWordIds
        )) {
            viewModel.allWords = words.filter { progress.wordsPracticedIds.contains($0.id) }
            viewModel.masteredIds = progress.masteredWordIds
            viewModel.bookmarkedIds = progress.bookmarkedWordIds
        }
    }
}

#Preview("Library - Light") {
    LibraryView()
        .withTheme(ThemeManager())
}

#Preview("Library - Dark") {
    LibraryView()
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
