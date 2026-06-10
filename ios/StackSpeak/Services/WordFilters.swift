import Foundation

struct WordFilters {
    var stack: WordStack?
    var level: Int?
    var masteredOnly: Bool = false
    var bookmarkedOnly: Bool = false
    var masteredIds: Set<UUID>?
    var bookmarkedIds: Set<UUID>?
}
