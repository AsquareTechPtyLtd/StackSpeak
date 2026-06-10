import Foundation
import SwiftData

@Model
final class PracticedSentence {
    var wordId: UUID
    var sentence: String
    var createdAt: Date
    var inputMethod: InputMethod

    init(wordId: UUID, sentence: String, createdAt: Date, inputMethod: InputMethod) {
        self.wordId = wordId
        self.sentence = sentence
        self.createdAt = createdAt
        self.inputMethod = inputMethod
    }
}
