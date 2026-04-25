import Testing
import Foundation
@testable import StackSpeak

@Suite("HomeViewModel Tests")
@MainActor
struct HomeViewModelTests {

    @Test("todaysWords computed property derives from wordsById")
    func testTodaysWordsComputed() async throws {
        let viewModel = HomeViewModel()

        #expect(viewModel.todaysWords.isEmpty)

        let word1 = createMockWord(id: UUID(), word: "algorithm")
        let word2 = createMockWord(id: UUID(), word: "refactor")

        viewModel.wordsById = [word1.id: word1, word2.id: word2]
        viewModel.dailySet = createMockDailySet(wordIds: [word1.id, word2.id])

        #expect(viewModel.todaysWords.count == 2)
        #expect(viewModel.todaysWords.contains { $0.word == "algorithm" })
        #expect(viewModel.todaysWords.contains { $0.word == "refactor" })
    }

    @Test("todaysWords reactively updates when wordsById changes")
    func testReactiveWordsById() async throws {
        let viewModel = HomeViewModel()

        let word1 = createMockWord(id: UUID(), word: "iterate")
        viewModel.dailySet = createMockDailySet(wordIds: [word1.id])

        #expect(viewModel.todaysWords.isEmpty)

        viewModel.wordsById = [word1.id: word1]

        #expect(viewModel.todaysWords.count == 1)
        #expect(viewModel.todaysWords.first?.word == "iterate")
    }

    @Test("isWordCompleted checks dailySet state")
    func testIsWordCompleted() async throws {
        let viewModel = HomeViewModel()
        let wordId = UUID()

        #expect(viewModel.isWordCompleted(wordId) == false)

        viewModel.dailySet = createMockDailySet(wordIds: [wordId], completedIds: [wordId])

        #expect(viewModel.isWordCompleted(wordId) == true)
    }

    @Test("isComingSoon is true when simpleDefinition is empty")
    func testComingSoonMissingSimple() async throws {
        let viewModel = HomeViewModel()
        let word = createMockWord(id: UUID(), word: "webhook",
                                  simpleDefinition: "",
                                  connector: "Think of it like a doorbell")
        #expect(viewModel.isComingSoon(word) == true)
    }

    @Test("isComingSoon is true when connector is empty")
    func testComingSoonMissingConnector() async throws {
        let viewModel = HomeViewModel()
        let word = createMockWord(id: UUID(), word: "webhook",
                                  simpleDefinition: "A way to get pushed updates.",
                                  connector: "")
        #expect(viewModel.isComingSoon(word) == true)
    }

    @Test("isComingSoon is false when both fields populated")
    func testComingSoonFullyBackfilled() async throws {
        let viewModel = HomeViewModel()
        let word = createMockWord(id: UUID(), word: "webhook",
                                  simpleDefinition: "A way to get pushed updates.",
                                  connector: "Think of it like a doorbell")
        #expect(viewModel.isComingSoon(word) == false)
    }

    @Test("isComingSoon treats whitespace-only as empty")
    func testComingSoonWhitespace() async throws {
        let viewModel = HomeViewModel()
        let word = createMockWord(id: UUID(), word: "webhook",
                                  simpleDefinition: "   ",
                                  connector: "Think of it like a doorbell")
        #expect(viewModel.isComingSoon(word) == true)
    }

    @Test("latestExplanation returns most recent PracticedSentence for the word")
    func testLatestExplanation() async throws {
        let viewModel = HomeViewModel()
        let progress = UserProgress()
        let targetId = UUID()
        let otherId = UUID()

        let older = PracticedSentence(
            wordId: targetId,
            sentence: "First explanation",
            createdAt: Date(timeIntervalSince1970: 1_000),
            inputMethod: .typed
        )
        let newer = PracticedSentence(
            wordId: targetId,
            sentence: "Second explanation",
            createdAt: Date(timeIntervalSince1970: 2_000),
            inputMethod: .voice
        )
        let unrelated = PracticedSentence(
            wordId: otherId,
            sentence: "Different word",
            createdAt: Date(timeIntervalSince1970: 3_000),
            inputMethod: .typed
        )
        progress.practicedSentences = [older, newer, unrelated]

        let latest = viewModel.latestExplanation(for: targetId, userProgress: progress)
        #expect(latest?.sentence == "Second explanation")
        #expect(latest?.inputMethod == .voice)
    }

    @Test("latestExplanation returns nil when no entries exist for the word")
    func testLatestExplanationMissing() async throws {
        let viewModel = HomeViewModel()
        let progress = UserProgress()
        #expect(viewModel.latestExplanation(for: UUID(), userProgress: progress) == nil)
    }

    // MARK: - Helpers

    private func createMockWord(
        id: UUID,
        word: String,
        simpleDefinition: String = "",
        connector: String = ""
    ) -> Word {
        Word(
            id: id,
            word: word,
            pronunciation: "/test/",
            partOfSpeech: "noun",
            shortDefinition: "Test definition",
            simpleDefinition: simpleDefinition,
            longDefinition: "Longer test definition",
            techContext: "Testing context",
            exampleSentence: "This is a test sentence.",
            etymology: "From test",
            connector: connector,
            codeExampleLanguage: "swift",
            codeExampleCode: "let x = 1",
            stack: WordStack.basicProgramming.rawValue,
            unlockLevel: 1,
            tags: []
        )
    }

    private func createMockDailySet(wordIds: [UUID], completedIds: [UUID] = []) -> DailySet {
        let set = DailySet(dayString: DailySet.todayString(), wordIds: wordIds)
        for id in completedIds {
            set.markWordCompleted(id)
        }
        return set
    }
}
