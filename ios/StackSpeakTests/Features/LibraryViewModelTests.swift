import Testing
import Foundation
@testable import StackSpeak

@Suite("LibraryViewModel Tests")
@MainActor
struct LibraryViewModelTests {

    @Test("filteredWords derives from allWords with no filters")
    func testFilteredWordsNoFilters() async throws {
        let viewModel = LibraryViewModel()

        let word1 = createMockWord(word: "algorithm", stack: .basicProgramming)
        let word2 = createMockWord(word: "refactor", stack: .intermediateCodeQuality)

        viewModel.allWords = [word1, word2]

        #expect(viewModel.filteredWords.count == 2)
    }

    @Test("filteredWords filters by stack")
    func testFilteredWordsByStack() async throws {
        let viewModel = LibraryViewModel()

        let word1 = createMockWord(word: "algorithm", stack: .basicProgramming)
        let word2 = createMockWord(word: "refactor", stack: .intermediateCodeQuality)
        let word3 = createMockWord(word: "iterate", stack: .basicProgramming)

        viewModel.allWords = [word1, word2, word3]
        viewModel.selectedStack = .basicProgramming

        #expect(viewModel.filteredWords.count == 2)
        #expect(viewModel.filteredWords.allSatisfy { $0.wordStack == .basicProgramming })
    }

    @Test("filteredWords filters by search query")
    func testFilteredWordsBySearch() async throws {
        let viewModel = LibraryViewModel()

        let word1 = createMockWord(word: "algorithm", stack: .basicProgramming)
        let word2 = createMockWord(word: "refactor", stack: .intermediateCodeQuality)
        let word3 = createMockWord(word: "algorithmic", stack: .advancedAlgorithms)

        viewModel.allWords = [word1, word2, word3]
        viewModel.searchQuery = "algo"

        #expect(viewModel.filteredWords.count == 2)
        #expect(viewModel.filteredWords.contains { $0.word == "algorithm" })
        #expect(viewModel.filteredWords.contains { $0.word == "algorithmic" })
    }

    @Test("filteredWords filters by both stack and search")
    func testFilteredWordsByStackAndSearch() async throws {
        let viewModel = LibraryViewModel()

        let word1 = createMockWord(word: "algorithm", stack: .advancedAlgorithms)
        let word2 = createMockWord(word: "refactor", stack: .intermediateCodeQuality)
        let word3 = createMockWord(word: "binary search", stack: .advancedAlgorithms)

        viewModel.allWords = [word1, word2, word3]
        viewModel.selectedStack = .advancedAlgorithms
        viewModel.searchQuery = "search"

        #expect(viewModel.filteredWords.count == 1)
        #expect(viewModel.filteredWords.first?.word == "binary search")
    }

    @Test("filteredWords reactively updates when filters change")
    func testReactiveFiltering() async throws {
        let viewModel = LibraryViewModel()

        let word1 = createMockWord(word: "algorithm", stack: .advancedAlgorithms)
        let word2 = createMockWord(word: "refactor", stack: .intermediateCodeQuality)

        viewModel.allWords = [word1, word2]

        // Initially no filter
        #expect(viewModel.filteredWords.count == 2)

        // Apply stack filter
        viewModel.selectedStack = .advancedAlgorithms
        #expect(viewModel.filteredWords.count == 1)

        // Clear stack filter, apply search
        viewModel.selectedStack = nil
        viewModel.searchQuery = "ref"
        #expect(viewModel.filteredWords.count == 1)
        #expect(viewModel.filteredWords.first?.word == "refactor")
    }

    // MARK: - Helper Methods

    private func createMockWord(word: String, stack: WordStack) -> Word {
        Word(
            id: UUID(),
            word: word,
            pronunciation: "/test/",
            partOfSpeech: "noun",
            shortDefinition: "Test definition for \(word)",
            simpleDefinition: "",
            longDefinition: "Longer test definition",
            techContext: "Testing context",
            exampleSentence: "This is a test sentence.",
            etymology: "From test",
            connector: "",
            codeExampleLanguage: "swift",
            codeExampleCode: "let x = 1",
            stack: stack.rawValue,
            unlockLevel: 1,
            tags: []
        )
    }
}
