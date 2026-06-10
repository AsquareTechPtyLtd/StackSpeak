import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(category: "CardFlowView")

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
    @State private var isBookmarked = false
    @State private var saveError: Error?

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
        .alert(
            Text("saveError.title"),
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            ),
            presenting: saveError
        ) { _ in
            Button("common.ok") { saveError = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
        .task { await load() }
        .onChange(of: viewModel.currentIndex) { _, _ in
            refreshBookmarkState()
        }
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

                // .overlay, not .background — background paints behind the
                // divider's frame and leaves the line itself system gray.
                Divider().overlay(theme.colors.line)

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
                guard let card = viewModel.currentCard, let services else { return }
                do {
                    isBookmarked = try services.bookmark.toggle(card: card, in: bookId, chapterId: chapter.id)
                } catch {
                    logger.error("Failed to toggle card bookmark: \(error.localizedDescription, privacy: .public)")
                    saveError = error
                }
            } label: {
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
        if let progress = fetchBookProgress() {
            viewModel.recordChapterEntry(bookProgress: progress, chapterId: chapter.id)
            viewModel.resumeIfPossible(at: progress.currentCardId)
            do {
                try modelContext.save()
            } catch {
                logger.error("Failed to save chapter entry: \(error.localizedDescription, privacy: .public)")
                saveError = error
            }
        }
        refreshBookmarkState()
    }

    private func advance() {
        guard let progress = userProgress, let bookProgress = fetchBookProgress() else { return }
        let result = viewModel.markComplete(
            bookProgress: bookProgress,
            userProgress: progress,
            override: false
        )
        applyAdvance(result)
    }

    private func handleReadAnyway() {
        showCapReached = false
        guard let progress = userProgress, let bookProgress = fetchBookProgress() else { return }
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
            do {
                try modelContext.save()
            } catch {
                logger.error("Failed to save book progress: \(error.localizedDescription, privacy: .public)")
                saveError = error
            }
        case .chapterCompleted:
            do {
                try modelContext.save()
                dismiss()
            } catch {
                logger.error("Failed to save book progress: \(error.localizedDescription, privacy: .public)")
                saveError = error
            }
        case .capReached:
            showCapReached = true
        }
    }

    /// Thin error-surfacing wrapper — fetch/create logic lives in the ViewModel.
    private func fetchBookProgress() -> BookProgress? {
        do {
            return try viewModel.bookProgress(modelContext: modelContext, bookId: bookId)
        } catch {
            logger.error("Failed to fetch or create BookProgress: \(error.localizedDescription, privacy: .public)")
            saveError = error
            return nil
        }
    }

    /// Bookmark state is tracked as @State and refreshed on load/navigation —
    /// not polled inside the toolbar label on every render (which also
    /// swallowed errors via try?).
    private func refreshBookmarkState() {
        guard let card = viewModel.currentCard, let services else {
            isBookmarked = false
            return
        }
        do {
            isBookmarked = try services.bookmark.isBookmarked(cardId: card.id)
        } catch {
            logger.error("Failed to read bookmark state: \(error.localizedDescription, privacy: .public)")
            isBookmarked = false
        }
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
