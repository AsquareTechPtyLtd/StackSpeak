import SwiftUI
import SwiftData

/// "From the book: <Title>" link shown on a word detail when the word was authored
/// from a book. Tapping opens the source chapter for entitled users (Pro, or the
/// free book), or the existing paywall for free users on a locked book — mirroring
/// the Books-tab gating. Book-only refs (no resolved chapter) open the book's
/// chapter list.
struct BackingCardLink: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.userProgress) private var userProgress

    let backingCard: BackingCardRef

    @State private var book: BookSummary?
    @State private var lockState: BookLockState = .locked
    @State private var destination: Destination?

    private enum Destination: Identifiable {
        case paywall(BookSummary)
        case reader(BookSummary, ChapterSummary)
        case bookDetail(BookSummary)

        var id: String {
            switch self {
            case .paywall(let b): "paywall-\(b.id)"
            case .reader(let b, let c): "reader-\(b.id)-\(c.id)"
            case .bookDetail(let b): "detail-\(b.id)"
            }
        }
    }

    var body: some View {
        Group {
            if let book {
                Button { open(book) } label: { row(book) }
                    .buttonStyle(.plain)
            }
        }
        .task { await resolve() }
        .sheet(item: $destination) { dest in sheet(for: dest) }
    }

    private var isLocked: Bool { lockState == .locked }

    private func row(_ book: BookSummary) -> some View {
        HStack(spacing: theme.spacing.xs) {
            Image(systemName: isLocked ? "lock.fill" : "book.closed")
                .foregroundColor(theme.colors.inkFaint)
            Text(String(format: String(localized: "word.fromBook.format"), book.title))
                .font(TypographyTokens.footnote)
                .foregroundColor(theme.colors.accent)
                .multilineTextAlignment(.leading)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(theme.colors.inkFaint)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func resolve() async {
        guard let services, let userProgress, book == nil else { return }
        guard let catalog = try? await services.bookCatalog.loadCatalog(),
              let found = catalog.books.first(where: { $0.id == backingCard.bookId }) else { return }
        // Set lock state before the book so the row never flashes the wrong glyph.
        lockState = services.bookCatalog.lockState(for: found, userProgress: userProgress)
        book = found
    }

    private func open(_ book: BookSummary) {
        if isLocked {
            destination = .paywall(book)
            return
        }
        Task {
            // Resolve the chapter from the manifest so the reader lands on it.
            if let chapterId = backingCard.chapterId,
               let manifest = try? await BundledBookSource.main().loadManifest(bookId: book.id),
               let chapter = manifest.chapters.first(where: { $0.id == chapterId }) {
                destination = .reader(book, chapter)
            } else {
                destination = .bookDetail(book)
            }
        }
    }

    @ViewBuilder
    private func sheet(for dest: Destination) -> some View {
        switch dest {
        case .paywall(let book):
            BookLockedSheet(book: book)
                .presentationDetents([.medium])
        case .reader(let book, let chapter):
            NavigationStack {
                CardFlowView(bookId: book.id, bookTitle: book.title, chapter: chapter)
            }
        case .bookDetail(let book):
            NavigationStack {
                BookDetailView(book: book)
            }
        }
    }
}

// MARK: - Previews

#Preview("Backing Card Link — Light") {
    BackingCardLink(
        backingCard: BackingCardRef(bookId: "clean-code", chapterId: "ch-01", cardId: "card-001")
    )
    .padding()
    .environment(\.userProgress, UserProgress())
    .withTheme(ThemeManager())
}

#Preview("Backing Card Link — Dark") {
    BackingCardLink(
        backingCard: BackingCardRef(bookId: "clean-code", chapterId: "ch-01", cardId: "card-001")
    )
    .padding()
    .environment(\.userProgress, UserProgress())
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}
