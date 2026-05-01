import Foundation
import SwiftData

/// View state for the card-flow inside a chapter. Owns:
///   - the loaded card list (in memory only — never SwiftData-persisted)
///   - the current card index, with prev/next clamped at chapter boundaries
///   - mark-complete writes to `BookProgress.completedCardIds` (idempotent)
///   - per-book streak increment + book daily-cap counter on the *first* card
///     of a new local day
///   - a soft cap-reached state when the user has set a personal daily limit
@MainActor
@Observable
final class CardFlowViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum AdvanceResult: Equatable {
        /// Card complete, advanced to the next one (or, on the last card, marked the chapter complete).
        case advanced(toIndex: Int)
        /// Last card in the chapter just completed; caller should pop to Book Detail.
        case chapterCompleted
        /// User hit their self-set book daily cap — view shows a soft override prompt.
        case capReached
    }

    var loadState: LoadState = .idle
    private(set) var cards: [BookCard] = []
    var currentIndex: Int = 0

    var currentCard: BookCard? {
        guard cards.indices.contains(currentIndex) else { return nil }
        return cards[currentIndex]
    }

    var totalCards: Int { cards.count }

    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex < cards.count - 1 }

    /// Loads the chapter cards via the content source. Caller holds the manifest
    /// and resolves the chapter; we just hydrate cards into memory for this session.
    func load(
        bookId: String,
        chapter: ChapterSummary,
        contentSource: any BookContentSource
    ) async {
        loadState = .loading
        do {
            cards = try await contentSource.loadChapter(
                bookId: bookId,
                chapterId: chapter.id,
                shards: chapter.shards
            )
            currentIndex = 0
            loadState = .loaded
        } catch {
            cards = []
            loadState = .failed(error.localizedDescription)
        }
    }

    /// Resumes a chapter at a specific card if `bookProgress.currentCardId` falls
    /// inside the loaded chapter. Otherwise leaves the index at 0.
    func resumeIfPossible(at cardId: String?) {
        guard let cardId,
              let idx = cards.firstIndex(where: { $0.id == cardId }) else { return }
        currentIndex = idx
    }

    /// Move the cursor backwards. Clamped at 0.
    func previous() {
        currentIndex = max(0, currentIndex - 1)
    }

    /// Move the cursor forwards. Clamped at the last card index.
    func next() {
        currentIndex = min(cards.count - 1, currentIndex + 1)
    }

    /// Marks the current card complete and advances. Writes are idempotent so
    /// double-tap does the same thing as single-tap.
    /// - Parameters:
    ///   - bookProgress: the per-book progress row to mutate
    ///   - userProgress: the global user progress row (for cap counter writes)
    ///   - override: pass `true` from the "Read one more anyway" affordance to
    ///     bypass the cap once
    ///   - now: injected for testability
    ///   - calendar: injected for testability
    /// - Returns: the advancement outcome — see `AdvanceResult`.
    @discardableResult
    func markComplete(
        bookProgress: BookProgress,
        userProgress: UserProgress,
        override: Bool = false,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AdvanceResult {
        guard let card = currentCard else {
            return .chapterCompleted
        }

        // Refresh the global cap counter against the current local day before checking.
        userProgress.refreshBookCardsReadIfNeeded(now: now, calendar: calendar)

        // Cap gate — only blocks when the user has opted into a limit and has hit it.
        // The override flag punches through for one read.
        if !override, let limit = userProgress.dailyBookCardLimit, userProgress.bookCardsReadToday >= limit {
            return .capReached
        }

        // Streak: counts only on the first card read in a given local day.
        let today = Self.dayString(from: now, calendar: calendar)
        let yesterday = Self.dayString(
            from: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
            calendar: calendar
        )
        if bookProgress.lastReadingDayString != today {
            bookProgress.recordReadDay(today: today, yesterday: yesterday)
        }

        // Counters + completion (idempotent on the card ID).
        let alreadyCompleted = bookProgress.completedCardIds.contains(card.id)
        if !alreadyCompleted {
            bookProgress.markCardCompleted(card.id)
            userProgress.recordBookCardRead(now: now, calendar: calendar)
        }

        // Resume metadata. Chapter id is set by `recordChapterEntry` on chapter open;
        // the card id advances per `markComplete`.
        bookProgress.currentCardId = card.id

        // Advance: at the last card the chapter is complete; otherwise step forward.
        if currentIndex == cards.count - 1 {
            return .chapterCompleted
        } else {
            currentIndex += 1
            return .advanced(toIndex: currentIndex)
        }
    }

    /// Sets `BookProgress.currentChapterId` so resume-on-reopen lands the user
    /// in the right chapter. View calls this once on chapter open.
    func recordChapterEntry(bookProgress: BookProgress, chapterId: String) {
        bookProgress.currentChapterId = chapterId
    }

    static func dayString(from date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
