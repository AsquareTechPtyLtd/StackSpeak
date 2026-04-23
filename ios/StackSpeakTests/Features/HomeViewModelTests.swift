import Testing
import Foundation
@testable import StackSpeak

@Suite("HomeViewModel Tests")
struct HomeViewModelTests {

    @Test("todaysWords computed property derives from wordsById")
    func testTodaysWordsComputed() async throws {
        let viewModel = HomeViewModel()

        // Initially empty
        #expect(viewModel.todaysWords.isEmpty)

        // Create mock daily set and words
        let word1 = createMockWord(id: UUID(), word: "algorithm")
        let word2 = createMockWord(id: UUID(), word: "refactor")

        viewModel.wordsById = [
            word1.id: word1,
            word2.id: word2
        ]

        viewModel.dailySet = createMockDailySet(wordIds: [word1.id, word2.id])

        // todaysWords should be computed from dailySet.wordIds + wordsById
        #expect(viewModel.todaysWords.count == 2)
        #expect(viewModel.todaysWords.contains { $0.word == "algorithm" })
        #expect(viewModel.todaysWords.contains { $0.word == "refactor" })
    }

    @Test("todaysWords reactively updates when wordsById changes")
    func testReactiveWordsById() async throws {
        let viewModel = HomeViewModel()

        let word1 = createMockWord(id: UUID(), word: "iterate")
        viewModel.dailySet = createMockDailySet(wordIds: [word1.id])

        // Initially no words loaded
        #expect(viewModel.todaysWords.isEmpty)

        // Add word to dictionary
        viewModel.wordsById = [word1.id: word1]

        // todaysWords should now reflect the change
        #expect(viewModel.todaysWords.count == 1)
        #expect(viewModel.todaysWords.first?.word == "iterate")
    }

    @Test("isWordCompleted checks dailySet state")
    func testIsWordCompleted() async throws {
        let viewModel = HomeViewModel()
        let wordId = UUID()

        // No daily set - should return false
        #expect(viewModel.isWordCompleted(wordId) == false)

        // Set daily set with completed word
        viewModel.dailySet = createMockDailySet(wordIds: [wordId], completedIds: [wordId])

        #expect(viewModel.isWordCompleted(wordId) == true)
    }

    // MARK: - Helper Methods

    private func createMockWord(id: UUID, word: String) -> Word {
        Word(
            id: id,
            word: word,
            pronunciation: "/test/",
            partOfSpeech: "noun",
            shortDefinition: "Test definition",
            simpleDefinition: "",
            longDefinition: "Longer test definition",
            techContext: "Testing context",
            exampleSentence: "This is a test sentence.",
            etymology: "From test",
            connector: "",
            codeExampleLanguage: "swift",
            codeExampleCode: "let x = 1",
            stack: WordStack.basicProgramming.rawValue,
            unlockLevel: 1,
            tags: []
        )
    }

    private func createMockDailySet(wordIds: [UUID], completedIds: [UUID] = []) -> DailySet {
        let set = DailySet(
            dayString: DailySet.todayString(),
            wordIds: wordIds,
            completedWordIds: Set(completedIds)
        )
        return set
    }
}
