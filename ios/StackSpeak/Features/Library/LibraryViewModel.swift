import Foundation

@MainActor
@Observable
final class LibraryViewModel {
    // Now stores all loaded words and derives filtered list
    var allWords: [Word] = []
    var searchQuery = ""
    var selectedStack: WordStack?
    var masteredIds: Set<UUID> = []
    var bookmarkedIds: Set<UUID> = []

    // Computed property - always reflects current filter state
    var filteredWords: [Word] {
        var result = allWords

        // Filter by stack
        if let stack = selectedStack {
            result = result.filter { $0.stack == stack.rawValue }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.word.lowercased().contains(query) ||
                $0.shortDefinition.lowercased().contains(query)
            }
        }

        return result
    }
}
