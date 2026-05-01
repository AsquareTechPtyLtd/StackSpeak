import Foundation
import SwiftData

/// Per-book reading state. One row per book the user has opened.
/// `completedCardIdsStorage` is a CSV of card IDs (cards are content, not DB rows).
@Model
final class BookProgress {
    @Attribute(.unique) var bookId: String
    var lastOpenedAt: Date
    var currentChapterId: String?
    var currentCardId: String?
    var completedCardIdsStorage: String

    /// Local-day key of the last day the user read at least one card in this book.
    /// Empty string means the book has never been read.
    var lastReadingDayString: String
    var currentStreakDays: Int
    var longestStreakDays: Int

    var completedCardIds: Set<String> {
        get {
            guard !completedCardIdsStorage.isEmpty else { return [] }
            return Set(completedCardIdsStorage.components(separatedBy: ","))
        }
        set {
            completedCardIdsStorage = newValue.sorted().joined(separator: ",")
        }
    }

    init(bookId: String) {
        self.bookId = bookId
        self.lastOpenedAt = Date()
        self.currentChapterId = nil
        self.currentCardId = nil
        self.completedCardIdsStorage = ""
        self.lastReadingDayString = ""
        self.currentStreakDays = 0
        self.longestStreakDays = 0
    }
}

/// A bookmarked book card. Surfaces under the You tab alongside word bookmarks.
@Model
final class BookmarkedCard {
    @Attribute(.unique) var cardId: String
    var bookId: String
    var chapterId: String
    var bookmarkedAt: Date

    init(cardId: String, bookId: String, chapterId: String, bookmarkedAt: Date = Date()) {
        self.cardId = cardId
        self.bookId = bookId
        self.chapterId = chapterId
        self.bookmarkedAt = bookmarkedAt
    }
}

extension BookProgress {
    /// Records that the user read at least one card today. Idempotent within a day.
    /// `today` and `yesterday` are passed in to keep the call deterministic across timezones / tests.
    func recordReadDay(today: String, yesterday: String) {
        if lastReadingDayString == today { return }
        if lastReadingDayString == yesterday {
            currentStreakDays += 1
        } else {
            currentStreakDays = 1
        }
        longestStreakDays = max(longestStreakDays, currentStreakDays)
        lastReadingDayString = today
    }

    /// Adds a card to the completed set. Idempotent.
    func markCardCompleted(_ cardId: String) {
        var ids = completedCardIds
        if ids.insert(cardId).inserted {
            completedCardIds = ids
        }
    }
}
