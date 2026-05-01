import SwiftUI
import SwiftData

/// The reading surface for one chapter — title, teaser, explanation, feynman.
/// Bottom toolbar provides prev / next + bookmark + mark-complete. Cap-reached
/// soft override surfaces as a sheet, not an inline blocker.
struct CardFlowView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let bookId: String
    let bookTitle: String
    let chapter: ChapterSummary

    @State private var viewModel = CardFlowViewModel()
    @State private var showCapReached = false
    @State private var bookmarkBump = false

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
                if let card = viewModel.currentCard {
                    cardScroll(card)
                } else {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "books.cardFlow.empty.title",
                        message: "books.cardFlow.empty.message"
                    )
                    .background(theme.colors.bg)
                }
            }
        }
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { bottomBar }
        .sheet(isPresented: $showCapReached) {
            CapReachedSheet(
                onAdjustLimit: { showCapReached = false },
                onReadAnyway: handleReadAnyway,
                onDismiss: { showCapReached = false }
            )
            .presentationDetents([.medium])
        }
        .task { await load() }
    }

    @ViewBuilder
    private func cardScroll(_ card: BookCard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                Text(String(format: String(localized: "books.cardFlow.counter.format"),
                            viewModel.currentIndex + 1,
                            viewModel.totalCards))
                    .font(TypographyTokens.caption.weight(.semibold))
                    .foregroundColor(theme.colors.inkFaint)
                    .accessibilityLabel(String(format: String(localized: "a11y.book.cardCounter.format"),
                                                 viewModel.currentIndex + 1,
                                                 viewModel.totalCards))

                Text(card.title)
                    .font(TypographyTokens.title1)
                    .foregroundColor(theme.colors.ink)

                Text(card.teaser)
                    .font(TypographyTokens.title3)
                    .foregroundColor(theme.colors.inkMuted)

                Divider().background(theme.colors.line)

                ForEach(Array(card.explanation.enumerated()), id: \.offset) { _, block in
                    ContentBlockView(block: block, bookId: bookId)
                }

                if !card.feynman.isEmpty {
                    Text("books.cardFlow.section.feynman")
                        .font(TypographyTokens.caption.weight(.semibold))
                        .foregroundColor(theme.colors.accent)
                        .padding(.top, theme.spacing.md)
                    ForEach(Array(card.feynman.enumerated()), id: \.offset) { _, block in
                        ContentBlockView(block: block, bookId: bookId)
                    }
                }
            }
            .padding(theme.spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.colors.bg)
    }

    @ToolbarContentBuilder
    private var bottomBar: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                viewModel.previous()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!viewModel.canGoBack)
            .accessibilityLabel("books.cardFlow.previous")

            Spacer()

            Button {
                bookmarkBump.toggle()
                guard let card = viewModel.currentCard else { return }
                _ = services?.bookmark.toggle(card: card, in: bookId, chapterId: chapter.id)
            } label: {
                let isBookmarked = viewModel.currentCard
                    .map { services?.bookmark.isBookmarked(cardId: $0.id) ?? false }
                    ?? false
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .symbolEffect(.bounce, value: bookmarkBump)
            }
            .accessibilityLabel("books.cardFlow.bookmark")

            Spacer()

            Button {
                advance()
            } label: {
                Image(systemName: viewModel.canGoForward ? "chevron.right" : "checkmark")
            }
            .accessibilityLabel(viewModel.canGoForward
                                ? "books.cardFlow.next"
                                : "books.cardFlow.finish")
        }
    }

    private func load() async {
        await viewModel.load(
            bookId: bookId,
            chapter: chapter,
            contentSource: BundledBookSource.main()
        )

        // Mark this chapter as the resume point and try to land on the resume card.
        if let progress = fetchOrCreateBookProgress() {
            viewModel.recordChapterEntry(bookProgress: progress, chapterId: chapter.id)
            viewModel.resumeIfPossible(at: progress.currentCardId)
            try? modelContext.save()
        }
    }

    private func advance() {
        guard let progress = userProgress, let bookProgress = fetchOrCreateBookProgress() else { return }
        let result = viewModel.markComplete(
            bookProgress: bookProgress,
            userProgress: progress,
            override: false
        )
        applyAdvance(result)
    }

    private func handleReadAnyway() {
        showCapReached = false
        guard let progress = userProgress, let bookProgress = fetchOrCreateBookProgress() else { return }
        let result = viewModel.markComplete(
            bookProgress: bookProgress,
            userProgress: progress,
            override: true
        )
        applyAdvance(result)
    }

    private func applyAdvance(_ result: CardFlowViewModel.AdvanceResult) {
        switch result {
        case .advanced:
            try? modelContext.save()
        case .chapterCompleted:
            try? modelContext.save()
            dismiss()
        case .capReached:
            showCapReached = true
        }
    }

    private func fetchOrCreateBookProgress() -> BookProgress? {
        let descriptor = FetchDescriptor<BookProgress>(
            predicate: #Predicate { $0.bookId == bookId }
        )
        if let existing = try? modelContext.fetch(descriptor).first { return existing }
        let new = BookProgress(bookId: bookId)
        modelContext.insert(new)
        return new
    }
}

/// Sheet shown when the user has hit their self-set book daily cap.
private struct CapReachedSheet: View {
    @Environment(\.theme) private var theme
    let onAdjustLimit: () -> Void
    let onReadAnyway: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            Image(systemName: "leaf.fill")
                .font(.system(.largeTitle))
                .foregroundColor(theme.colors.good)
                .padding(.top, theme.spacing.xl)
            Text("books.cap.title")
                .font(TypographyTokens.title2)
                .foregroundColor(theme.colors.ink)
            Text("books.cap.message")
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.lg)
            Spacer()
            VStack(spacing: theme.spacing.sm) {
                PrimaryCTAButton("books.cap.readAnyway", action: onReadAnyway)
                Button("books.cap.adjustLimit", action: onAdjustLimit)
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.accent)
                Button("common.cancel", action: onDismiss)
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.inkMuted)
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .background(theme.colors.bg)
    }
}
