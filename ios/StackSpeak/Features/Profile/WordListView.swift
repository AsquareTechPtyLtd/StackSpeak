import SwiftUI

/// Pushed from Profile's "Mastered" / "Bookmarked" rows (P2). Shows a simple
/// list of the words that match the given id set, sorted alphabetically.
/// Tapping a row opens Word Detail.
struct WordListView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.userProgress) private var userProgress

    let title: LocalizedStringKey
    let wordIds: Set<UUID>
    let emptyTitle: LocalizedStringKey
    let emptyMessage: LocalizedStringKey

    @State private var words: [Word] = []

    var body: some View {
        Group {
            if wordIds.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: emptyTitle,
                    message: emptyMessage
                )
                .background(theme.colors.bg)
            } else {
                List {
                    if let progress = userProgress {
                        ForEach(words) { word in
                            NavigationLink {
                                WordDetailView(word: word, userProgress: progress)
                            } label: {
                                wordRow(word: word, progress: progress)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(theme.colors.bg)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
    }

    private func wordRow(word: Word, progress: UserProgress) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: theme.spacing.xs) {
                Text(word.word)
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.ink)
                if progress.masteredWordIds.contains(word.id) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(.caption))
                        .foregroundColor(theme.colors.good)
                        .accessibilityLabel(String(localized: "a11y.mastered"))
                }
                if progress.bookmarkedWordIds.contains(word.id) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(.caption2))
                        .foregroundColor(theme.colors.accent)
                        .accessibilityLabel(String(localized: "a11y.bookmarked"))
                }
            }
            Text(word.shortDefinition)
                .font(TypographyTokens.subheadline)
                .foregroundColor(theme.colors.inkMuted)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        guard let services else { return }
        var loaded: [Word] = []
        for id in wordIds {
            guard !Task.isCancelled else { return }
            if let word = try? services.word.fetchWord(byId: id) {
                loaded.append(word)
            }
        }
        words = loaded.sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
    }
}
