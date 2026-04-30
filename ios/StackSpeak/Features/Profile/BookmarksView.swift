import SwiftUI
import SwiftData

/// Consolidated bookmarks under the You tab. Two sections: saved cards and
/// saved words. Replaces the prior single-section "Saved" entry.
struct BookmarksView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.userProgress) private var userProgress

    @State private var viewModel = BookmarksViewModel()
    @State private var resolvedWords: [Word] = []

    var body: some View {
        Group {
            if !viewModel.hasAnyBookmarks {
                EmptyStateView(
                    icon: "bookmark",
                    title: "bookmarks.empty.title",
                    message: "bookmarks.empty.message"
                )
                .background(theme.colors.bg)
            } else {
                List {
                    if !viewModel.cardRows.isEmpty {
                        Section("bookmarks.section.cards") {
                            ForEach(viewModel.cardRows) { row in
                                cardRow(row)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            services?.bookmark.remove(cardId: row.id)
                                            Task { await load() }
                                        } label: {
                                            Label("common.remove", systemImage: "bookmark.slash")
                                        }
                                    }
                            }
                        }
                    }

                    if !resolvedWords.isEmpty {
                        Section("bookmarks.section.words") {
                            ForEach(resolvedWords) { word in
                                if let progress = userProgress {
                                    NavigationLink {
                                        WordDetailView(word: word, userProgress: progress)
                                    } label: {
                                        wordRow(word: word, progress: progress)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(theme.colors.bg)
            }
        }
        .navigationTitle("bookmarks.navTitle")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
    }

    private func cardRow(_ row: BookmarksViewModel.CardRow) -> some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: "doc.text")
                .font(.system(size: 14))
                .foregroundColor(theme.colors.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.cardTitle)
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.ink)
                Text(row.bookTitle)
                    .font(TypographyTokens.subheadline)
                    .foregroundColor(theme.colors.inkMuted)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func wordRow(word: Word, progress: UserProgress) -> some View {
        VStack(alignment: .leading, spacing: 2) {
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
            }
            Text(word.shortDefinition)
                .font(TypographyTokens.subheadline)
                .foregroundColor(theme.colors.inkMuted)
                .lineLimit(2)
        }
    }

    private func load() async {
        guard let services else { return }
        await viewModel.load(
            userProgress: userProgress,
            catalogService: services.bookCatalog,
            contentSource: BundledBookSource.main(),
            bookmarkRepository: services.bookmark
        )
        // Resolve word rows alongside.
        var loaded: [Word] = []
        for id in viewModel.wordIds {
            if let word = try? services.word.fetchWord(byId: id) {
                loaded.append(word)
            }
        }
        resolvedWords = loaded.sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
    }
}
