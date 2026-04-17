import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Query private var userProgressList: [UserProgress]

    @StateObject private var viewModel = LibraryViewModel()
    @State private var searchText = ""

    var userProgress: UserProgress? {
        userProgressList.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: theme.spacing.md) {
                        filtersSection

                        if viewModel.filteredWords.isEmpty {
                            emptyState
                        } else {
                            wordsListSection
                        }
                    }
                    .padding(theme.spacing.lg)
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search words")
            .onChange(of: searchText) { _, newValue in
                viewModel.searchQuery = newValue
                performSearch()
            }
            .task {
                performSearch()
            }
        }
    }

    private var filtersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.sm) {
                FilterChip(
                    title: "All",
                    isSelected: viewModel.selectedStack == nil,
                    action: { viewModel.selectedStack = nil; performSearch() }
                )

                ForEach(WordStack.allCases) { stack in
                    FilterChip(
                        title: stack.displayName,
                        isSelected: viewModel.selectedStack == stack,
                        action: { viewModel.selectedStack = stack; performSearch() }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacing.lg) {
            Image(systemName: "books.vertical")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(theme.colors.inkFaint)

            Text("No words found")
                .font(TypographyTokens.title2)
                .foregroundColor(theme.colors.ink)

            Text("Try adjusting your search or filters.")
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.inkMuted)
        }
        .padding(.top, theme.spacing.xxxl)
    }

    private var wordsListSection: some View {
        LazyVStack(spacing: theme.spacing.md) {
            ForEach(viewModel.filteredWords) { word in
                if let progress = userProgress {
                    NavigationLink(destination: WordDetailView(word: word, userProgress: progress)) {
                        WordRowView(word: word, userProgress: progress)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func performSearch() {
        let filters = WordFilters(
            stack: viewModel.selectedStack,
            level: nil
        )

        if let words = try? WordService(modelContext: modelContext).fetchWords(matching: searchText, filters: filters) {
            viewModel.filteredWords = words
        }
    }
}

struct FilterChip: View {
    @Environment(\.theme) private var theme

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TypographyTokens.callout)
                .foregroundColor(isSelected ? .white : theme.colors.ink)
                .padding(.horizontal, theme.spacing.md)
                .padding(.vertical, theme.spacing.sm)
                .background(isSelected ? theme.colors.accent : theme.colors.surface)
                .cornerRadius(20)
        }
    }
}

struct WordRowView: View {
    @Environment(\.theme) private var theme

    let word: Word
    let userProgress: UserProgress

    var isPracticed: Bool {
        userProgress.wordsPracticedIds.contains(word.id)
    }

    var isMastered: Bool {
        userProgress.masteredWordIds.contains(word.id)
    }

    var isBookmarked: Bool {
        userProgress.bookmarkedWordIds.contains(word.id)
    }

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                HStack {
                    Text(word.word)
                        .font(TypographyTokens.headline)
                        .foregroundColor(theme.colors.ink)

                    if isMastered {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(theme.colors.good)
                    }

                    if isBookmarked {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 12))
                            .foregroundColor(theme.colors.accent)
                    }
                }

                Text(word.shortDefinition)
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
                    .lineLimit(2)

                HStack(spacing: theme.spacing.sm) {
                    Text(word.stack.displayName)
                        .font(TypographyTokens.caption)
                        .foregroundColor(theme.colors.inkFaint)

                    Text("·")
                        .foregroundColor(theme.colors.inkFaint)

                    Text("L\(word.unlockLevel)")
                        .font(TypographyTokens.mono)
                        .foregroundColor(theme.colors.inkFaint)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(theme.colors.inkFaint)
        }
        .padding(theme.spacing.rowPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(8)
    }
}
