import SwiftUI

struct LibraryView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.userProgress) private var userProgress

    @State private var viewModel = LibraryViewModel()
    @State private var searchText = ""

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
                    .frame(maxWidth: 720)
                    .padding(theme.spacing.lg)
                }
            }
            .navigationTitle("library.navTitle")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "library.search.prompt")
            .onChange(of: searchText) { _, newValue in
                viewModel.searchQuery = newValue
            }
            .task {
                await loadAllWords()
            }
            .onChange(of: userProgress?.masteredWordIds) { _, newIds in
                viewModel.masteredIds = newIds ?? []
            }
            .onChange(of: userProgress?.bookmarkedWordIds) { _, newIds in
                viewModel.bookmarkedIds = newIds ?? []
            }
        }
    }

    private var filtersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.sm) {
                FilterChip(
                    title: String(localized: "library.filter.all"),
                    isSelected: viewModel.selectedStack == nil,
                    action: { viewModel.selectedStack = nil }
                )

                ForEach(WordStack.allCases) { stack in
                    FilterChip(
                        title: stack.displayName,
                        isSelected: viewModel.selectedStack == stack,
                        action: { viewModel.selectedStack = stack }
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
                .accessibilityHidden(true)

            Text("library.empty.title")
                .font(TypographyTokens.title2)
                .foregroundColor(theme.colors.ink)

            Text("library.empty.message")
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.inkMuted)
        }
        .padding(.top, theme.spacing.xxxl)
    }

    private var wordsListSection: some View {
        LazyVStack(spacing: theme.spacing.md) {
            ForEach(viewModel.filteredWords) { word in
                if let progress = userProgress {
                    NavigationLink(destination: NavigationStack { WordDetailView(word: word, userProgress: progress) }) {
                        WordRowView(word: word, userProgress: progress)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loadAllWords() async {
        guard let progress = userProgress, let services else { return }
        // Load all words once - filtering happens via computed property
        if let words = try? services.word.fetchWords(matching: "", filters: WordFilters(
            stack: nil,
            level: nil,
            masteredIds: progress.masteredWordIds,
            bookmarkedIds: progress.bookmarkedWordIds
        )) {
            viewModel.allWords = words
            viewModel.masteredIds = progress.masteredWordIds
            viewModel.bookmarkedIds = progress.bookmarkedWordIds
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
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct WordRowView: View {
    @Environment(\.theme) private var theme

    let word: Word
    let userProgress: UserProgress

    var isPracticed: Bool { userProgress.wordsPracticedIds.contains(word.id) }
    var isMastered: Bool  { userProgress.masteredWordIds.contains(word.id) }
    var isBookmarked: Bool { userProgress.bookmarkedWordIds.contains(word.id) }

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
                            .accessibilityLabel(String(localized: "a11y.mastered"))
                    }

                    if isBookmarked {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 12))
                            .foregroundColor(theme.colors.accent)
                            .accessibilityLabel(String(localized: "a11y.bookmarked"))
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
                        .accessibilityHidden(true)

                    Text("L\(word.unlockLevel)")
                        .font(TypographyTokens.mono)
                        .foregroundColor(theme.colors.inkFaint)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(theme.colors.inkFaint)
                .accessibilityHidden(true)
        }
        .padding(theme.spacing.rowPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(word.word). \(word.shortDefinition).\(isMastered ? " " + String(localized: "a11y.mastered") + "." : "")\(isBookmarked ? " " + String(localized: "a11y.bookmarked") + "." : "")")
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
