import SwiftUI
import SwiftData

private let previewLockedBook = BookSummary(
    id: "pro-book-preview",
    title: "Advanced SwiftData",
    author: "Alex Engineer",
    summary: "Relationships, migrations, and CloudKit sync with SwiftData.",
    coverIcon: "cylinder.split.1x2",
    accentHex: nil,
    tags: ["swiftdata", "ios"],
    categories: [.codeCraft],
    chapterCount: 8,
    cardCount: 56,
    manifestVersion: 1,
    manifestPath: "books/pro-book-preview/manifest.json",
    freeForAll: false,
    sizeBytes: 307_200
)

/// Locked-book gate shown when a non-pro user taps a pro book — from the
/// Books tab or from a word's "From the book" link. The CTA opens the Pro
/// paywall (`ProGateSheet`).
struct BookLockedSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.userProgress) private var userProgress

    @State private var showProSheet = false

    let book: BookSummary

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: theme.spacing.lg) {
                Image(systemName: "lock.fill")
                    .scaledIcon(size: IconSizeTokens.large, weight: .semibold)
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

                PrimaryCTAButton("books.locked.cta") { showProSheet = true }

                Button { dismiss() } label: {
                    Text("common.notNow")
                        .font(TypographyTokens.footnote.weight(.medium))
                        .foregroundColor(theme.colors.inkMuted)
                }
            }
            .padding(theme.spacing.xl)

            Spacer()
        }
        .background(theme.colors.bg.ignoresSafeArea())
        .sheet(isPresented: $showProSheet) {
            ProGateSheet()
        }
        // Once the paywall (or dev toggle) grants Pro, this gate has nothing
        // left to gate — dismiss so the unlocked book is immediately tappable.
        .onChange(of: userProgress?.isProActive ?? false) { _, isPro in
            if isPro { dismiss() }
        }
    }

}

#Preview("Book Locked Sheet — Light") {
    BookLockedSheet(book: previewLockedBook)
        .withTheme(ThemeManager())
        .environment(\.userProgress, UserProgress())
        .modelContainer(for: [UserProgress.self, BookProgress.self, BookmarkedCard.self],
                        inMemory: true)
}

#Preview("Book Locked Sheet — Dark") {
    BookLockedSheet(book: previewLockedBook)
        .withTheme(ThemeManager())
        .environment(\.userProgress, UserProgress())
        .modelContainer(for: [UserProgress.self, BookProgress.self, BookmarkedCard.self],
                        inMemory: true)
        .preferredColorScheme(.dark)
}
