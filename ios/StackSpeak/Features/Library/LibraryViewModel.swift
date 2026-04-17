import Foundation

@MainActor
@Observable
final class LibraryViewModel {
    var searchQuery = ""
    var selectedStack: WordStack?
    var filteredWords: [Word] = []
}
