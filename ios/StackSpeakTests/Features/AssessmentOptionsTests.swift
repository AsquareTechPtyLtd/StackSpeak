import Testing
import Foundation
@testable import StackSpeak

// `@MainActor` because `AssessmentView.buildDistractors` is MainActor-isolated
// (SwiftUI `View`); running the suite on the main actor lets it pass the
// non-Sendable `[Word]` fixtures without tripping Swift 6 strict concurrency.
@Suite("AssessmentView — distractor generation")
@MainActor
struct AssessmentOptionsTests {

    private func makeWord(
        _ term: String,
        def: String,
        stack: String = "alpha",
        category: String = "concepts",
        tags: [String] = [],
        level: Int = 1
    ) -> Word {
        Word(
            id: UUID(),
            word: term,
            pronunciation: "/\(term)/",
            partOfSpeech: "noun",
            shortDefinition: def,
            simpleDefinition: "s",
            longDefinition: "l",
            techContext: "t",
            exampleSentence: "e",
            etymology: "y",
            connector: "c",
            codeExampleLanguage: "swift",
            codeExampleCode: "let x = 1",
            stack: stack,
            unlockLevel: level,
            tags: tags,
            category: category
        )
    }

    private func progress(level: Int = 10, practiced: Set<UUID> = []) -> UserProgress {
        let p = UserProgress()
        p.level = level
        p.wordsPracticedIds = practiced
        return p
    }

    // MARK: - normalizedTerm

    @Test("normalizedTerm strips punctuation, case, and parentheticals")
    func normalization() {
        #expect(AssessmentView.normalizedTerm("B+ Tree") == "b tree")
        #expect(AssessmentView.normalizedTerm("Cache-Control (header)") == "cache control")
        #expect(AssessmentView.normalizedTerm("CAP Theorem") == AssessmentView.normalizedTerm("cap theorem"))
    }

    // MARK: - the two-correct-answers bug

    @Test("A same-term word from another stack is never a distractor")
    func excludesSameTermAcrossStacks() {
        let target = makeWord("CAP Theorem", def: "Correct definition", stack: "alpha")
        let twin = makeWord("CAP Theorem", def: "Differently worded but still correct", stack: "beta", category: "other")
        let fillers = (0..<5).map { makeWord("Filler \($0)", def: "Def \($0)", stack: "gamma") }

        let result = AssessmentView.buildDistractors(
            for: target, count: 3, allWords: [target, twin] + fillers, progress: progress())

        #expect(!result.contains(twin.shortDefinition))
        #expect(result.count == 3)
    }

    @Test("A word with the verbatim same definition is excluded")
    func excludesVerbatimSameDefinition() {
        let target = makeWord("Alpha", def: "Shared definition")
        let echo = makeWord("Beta", def: "Shared definition")
        let fillers = (0..<4).map { makeWord("F\($0)", def: "Unique \($0)") }

        let result = AssessmentView.buildDistractors(
            for: target, count: 3, allWords: [target, echo] + fillers, progress: progress())

        #expect(result.allSatisfy { $0 != "Shared definition" } || result.filter { $0 == "Shared definition" }.count == 1)
        #expect(!result.contains(where: { $0 == target.shortDefinition }))
    }

    // MARK: - topic affinity

    @Test("Same-stack distractors are preferred over unrelated ones")
    func prefersSameStack() {
        let target = makeWord("Target", def: "T", stack: "alpha", category: "x")
        let sameStack = (0..<3).map { makeWord("Near \($0)", def: "Near \($0)", stack: "alpha", category: "x") }
        let unrelated = (0..<5).map { makeWord("Far \($0)", def: "Far \($0)", stack: "zeta", category: "y") }

        let result = AssessmentView.buildDistractors(
            for: target, count: 3, allWords: [target] + sameStack + unrelated, progress: progress())

        #expect(Set(result) == Set(sameStack.map(\.shortDefinition)))
    }

    @Test("Within a tier, practiced words are preferred")
    func prefersPracticedWithinTier() {
        let target = makeWord("Target", def: "T", stack: "alpha")
        let practicedWords = (0..<3).map { makeWord("P\($0)", def: "P\($0)", stack: "alpha") }
        let freshWords = (0..<3).map { makeWord("U\($0)", def: "U\($0)", stack: "alpha") }
        let prog = progress(practiced: Set(practicedWords.map(\.id)))

        let result = AssessmentView.buildDistractors(
            for: target, count: 3, allWords: [target] + practicedWords + freshWords, progress: prog)

        #expect(Set(result) == Set(practicedWords.map(\.shortDefinition)))
    }

    // MARK: - eligibility

    @Test("Locked (above-level) words are excluded")
    func excludesLockedWords() {
        let target = makeWord("Target", def: "T", level: 1)
        let locked = makeWord("Locked", def: "Locked def", level: 99)
        let ok = (0..<3).map { makeWord("Ok \($0)", def: "Ok \($0)", level: 1) }

        let result = AssessmentView.buildDistractors(
            for: target, count: 3, allWords: [target, locked] + ok, progress: progress(level: 5))

        #expect(!result.contains("Locked def"))
    }

    @Test("Distractor definitions are unique and fill to count")
    func uniqueAndFilled() {
        let target = makeWord("Target", def: "T")
        let pool = (0..<10).map { makeWord("W\($0)", def: "Def \($0)") }

        let result = AssessmentView.buildDistractors(
            for: target, count: 3, allWords: [target] + pool, progress: progress())

        #expect(result.count == 3)
        #expect(Set(result).count == 3)
    }
}
