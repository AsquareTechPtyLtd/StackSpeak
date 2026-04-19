import Testing
import Foundation

// Mirror the private `containsWord` logic so it can be tested in isolation.
private func containsWord(_ sentence: String, target: String) -> Bool {
    let escaped = NSRegularExpression.escapedPattern(for: target)
    let pattern = "\\b\(escaped)(s|es|ed|ing|'s)?\\b"
    let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    let range = NSRange(sentence.startIndex..., in: sentence)
    return regex?.firstMatch(in: sentence, range: range) != nil
}

@Suite("Sentence validation — word containment")
struct SentenceValidationTests {

    @Test("Exact word match")
    func exactMatch() {
        #expect(containsWord("This operation is idempotent.", target: "idempotent"))
    }

    @Test("Case insensitive match")
    func caseInsensitive() {
        #expect(containsWord("IDEMPOTENT operations are safe.", target: "idempotent"))
    }

    @Test("Plural inflection -s")
    func pluralS() {
        #expect(containsWord("These abstractions leak.", target: "abstraction"))
    }

    @Test("Past tense -ed")
    func pastTenseEd() {
        #expect(containsWord("The cache was invalidated.", target: "invalidate"))
    }

    @Test("Progressive -ing")
    func progressiveIng() {
        #expect(containsWord("We are refactoring the module.", target: "refactor"))
    }

    @Test("Possessive 's")
    func possessive() {
        #expect(containsWord("The system's latency increased.", target: "system"))
    }

    @Test("Partial word does NOT match (whole-word boundary)")
    func noPartialMatch() {
        // "abstract" should not match sentence containing only "abstraction"
        #expect(!containsWord("This is an abstraction.", target: "abstract"))
    }

    @Test("Empty sentence returns false")
    func emptyFalse() {
        #expect(!containsWord("", target: "idempotent"))
    }

    @Test("Word not present returns false")
    func wordNotPresent() {
        #expect(!containsWord("The server crashed.", target: "idempotent"))
    }
}
