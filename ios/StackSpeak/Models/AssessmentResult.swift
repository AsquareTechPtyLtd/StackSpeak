import Foundation
import SwiftData

@Model
final class AssessmentResult {
    @Attribute(.unique) var id: UUID
    var wordId: UUID
    var attemptedAt: Date
    var isCorrect: Bool
    var selectedAnswer: String
    var correctAnswer: String

    init(wordId: UUID, attemptedAt: Date, isCorrect: Bool, selectedAnswer: String, correctAnswer: String) {
        self.id = UUID()
        self.wordId = wordId
        self.attemptedAt = attemptedAt
        self.isCorrect = isCorrect
        self.selectedAnswer = selectedAnswer
        self.correctAnswer = correctAnswer
    }
}
