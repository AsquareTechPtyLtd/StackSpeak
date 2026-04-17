import Foundation

@Observable
final class WordDetailViewModel {
    var word: Word
    var isBookmarked: Bool
    var isMastered: Bool

    init(word: Word, isBookmarked: Bool, isMastered: Bool) {
        self.word = word
        self.isBookmarked = isBookmarked
        self.isMastered = isMastered
    }

    func toggleBookmark() {
        isBookmarked.toggle()
    }

    func toggleMastered() {
        isMastered.toggle()
    }
}
