import Foundation

@Observable
final class SentencePracticeViewModel {
    var sentence = ""
    var inputMethod: InputMethod = .typed
    var isRecording = false
    var errorMessage: String?

    func validateSentence(for word: String) -> Bool {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            errorMessage = "Please write a sentence first."
            return false
        }

        let containsWord = trimmed.localizedCaseInsensitiveContains(word)
        guard containsWord else {
            errorMessage = "Your sentence must contain the word \"\(word)\"."
            return false
        }

        errorMessage = nil
        return true
    }

    func reset() {
        sentence = ""
        inputMethod = .typed
        isRecording = false
        errorMessage = nil
    }
}
