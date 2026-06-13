import Foundation
import SwiftData

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
