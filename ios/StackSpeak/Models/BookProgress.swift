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
