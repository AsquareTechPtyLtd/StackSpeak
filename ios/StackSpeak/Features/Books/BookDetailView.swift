import SwiftUI
import SwiftData

private let previewBookSummary = BookSummary(
    id: "preview-book",
    title: "Swift Concurrency",
    author: "Robin Swift",
    summary: "Actors, async/await, and structured concurrency for iOS developers.",
    coverIcon: "gearshape.2",
    accentHex: "#0A84FF",
    tags: ["swift", "concurrency"],
    categories: [.codeCraft],
    chapterCount: 5,
    cardCount: 38,
    manifestVersion: 1,
    manifestPath: "books/preview-book/manifest.json",
    freeForAll: false,
    sizeBytes: 204_800
)

/// Book Detail screen — pushed from the Books tab. Header (title/author/summary)
/// + ordered chapter list with `X / N` completion indicators.
struct BookDetailView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.userProgress) private var userProgress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let book: BookSummary

    @State private var viewModel = BookDetailViewModel()
    @State private var streakToastDays: Int?

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.colors.bg)
            case .failed(let message):
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "books.detail.failed.title",
                    message: LocalizedStringKey(message)
                )
                .background(theme.colors.bg)
            case .loaded:
                content
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if let days = streakToastDays {
                StreakToast(days: days)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, theme.spacing.md)
                    .task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        withAnimation(reduceMotion ? nil : MotionTokens.standard) {
                            streakToastDays = nil
                        }
                    }
            }
        }
        .task { await openBook() }
    }

    private var content: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: theme.spacing.sm) {
                    Text(book.title)
                        .font(TypographyTokens.title2)
                        .foregroundColor(theme.colors.ink)
                    if let author = book.author, !author.isEmpty {
                        Text(author)
                            .font(TypographyTokens.subheadline)
                            .foregroundColor(theme.colors.inkMuted)
                    }
                    Text(book.summary)
                        .font(TypographyTokens.body)
                        .foregroundColor(theme.colors.inkMuted)
                    Text(String(format: String(localized: "books.meta.format"), book.chapterCount, book.cardCount))
                        .font(TypographyTokens.caption)
                        .foregroundColor(theme.colors.inkFaint)
                }
                .padding(.vertical, theme.spacing.xs)
                .listRowBackground(theme.colors.surfaceAlt)
            }

            Section("books.detail.chapters") {
                ForEach(viewModel.orderedChapters) { chapter in
                    NavigationLink {
                        if let manifest = viewModel.manifest {
                            CardFlowView(
                                bookId: manifest.id,
                                bookTitle: book.title,
                                chapter: chapter
                            )
                        }
                    } label: {
                        chapterRow(chapter)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.colors.bg)
    }

    private func chapterRow(_ chapter: ChapterSummary) -> some View {
        let completed = viewModel.completedCount(for: chapter)
        return HStack(spacing: theme.spacing.md) {
            Image(systemName: chapter.icon)
                .font(.system(.subheadline))
                .foregroundColor(theme.colors.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(chapter.title)
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.ink)
                if !chapter.summary.isEmpty {
                    Text(chapter.summary)
                        .font(TypographyTokens.subheadline)
                        .foregroundColor(theme.colors.inkMuted)
                        .lineLimit(2)
                }
            }
            Spacer()
            Text(String(format: String(localized: "books.chapter.progress.format"), completed, chapter.cardCount))
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.inkFaint)
                .accessibilityLabel(String(
                    format: String(localized: "a11y.book.chapter.progress.format"),
                    completed,
                    chapter.cardCount
                ))
        }
    }

    private func openBook() async {
        // Don't open until app services are initialized (nil during the init-error state).
        guard services != nil else { return }
        await viewModel.open(
            bookId: book.id,
            contentSource: BundledBookSource.main(),
            modelContext: modelContext
        )
        if let days = viewModel.consumeStreakToast() {
            withAnimation(MotionTokens.standard) {
                streakToastDays = days
            }
        }
    }
}

#Preview("Book Detail — Light") {
    NavigationStack {
        BookDetailView(book: previewBookSummary)
    }
    .withTheme(ThemeManager())
    .environment(\.userProgress, UserProgress())
    .modelContainer(for: [BookProgress.self, BookmarkedCard.self, UserProgress.self],
                    inMemory: true)
}

#Preview("Book Detail — Dark") {
    NavigationStack {
        BookDetailView(book: previewBookSummary)
    }
    .withTheme(ThemeManager())
    .environment(\.userProgress, UserProgress())
    .modelContainer(for: [BookProgress.self, BookmarkedCard.self, UserProgress.self],
                    inMemory: true)
    .preferredColorScheme(.dark)
}
