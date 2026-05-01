import Testing
import Foundation
import SwiftData
@testable import StackSpeak

@Suite("Interleaving — selectQualifyingWords")
@MainActor
struct InterleavingTests {

    // MARK: - All 5 categories present

    @Test("Returns one word from each category when all 5 represented")
    func balancedSetWhenAllCategoriesPresent() throws {
        let service = try makeService()
        let words = [
            mockWord("concept-a", category: .concepts),
            mockWord("component-a", category: .components),
            mockWord("process-a", category: .processes),
            mockWord("pattern-a", category: .patterns),
            mockWord("quality-a", category: .qualities)
        ]
        let progress = mockProgress(stacks: ["test-stack"])

        let (selected, _) = service.selectQualifyingWords(
            from: words,
            startingAt: 0,
            userProgress: progress,
            count: 5
        )

        #expect(selected.count == 5)
        let categories = Set(selected.map { $0.category })
        #expect(categories.count == 5)
        #expect(categories.contains(.concepts))
        #expect(categories.contains(.components))
        #expect(categories.contains(.processes))
        #expect(categories.contains(.patterns))
        #expect(categories.contains(.qualities))
    }

    // MARK: - Backfill when category empty

    @Test("Backfills when one category is empty so result still has 5 words")
    func backfillsWhenOneCategoryMissing() throws {
        let service = try makeService()
        // No "qualities" words present
        let words = [
            mockWord("concept-a", category: .concepts),
            mockWord("concept-b", category: .concepts),
            mockWord("component-a", category: .components),
            mockWord("process-a", category: .processes),
            mockWord("pattern-a", category: .patterns)
        ]
        let progress = mockProgress(stacks: ["test-stack"])

        let (selected, _) = service.selectQualifyingWords(
            from: words,
            startingAt: 0,
            userProgress: progress,
            count: 5
        )

        #expect(selected.count == 5)
        // Should include both concepts to fill the missing qualities slot
        let conceptCount = selected.filter { $0.category == .concepts }.count
        #expect(conceptCount == 2)
    }

    @Test("Backfills heavily when only 2 categories available")
    func backfillsWhenMostCategoriesMissing() throws {
        let service = try makeService()
        // Only concepts and components — 3 categories empty
        let words = (1...10).map { i in
            mockWord("concept-\(i)", category: i.isMultiple(of: 2) ? .concepts : .components)
        }
        let progress = mockProgress(stacks: ["test-stack"])

        let (selected, _) = service.selectQualifyingWords(
            from: words,
            startingAt: 0,
            userProgress: progress,
            count: 5
        )

        #expect(selected.count == 5)
        let categories = Set(selected.map { $0.category })
        // Only 2 categories represented, but still 5 words via backfill
        #expect(categories.count == 2)
    }

    // MARK: - Edge cases

    @Test("Returns empty when no qualifying words")
    func returnsEmptyWhenNoQualifyingWords() throws {
        let service = try makeService()
        // Words exist but user hasn't selected the stack
        let words = [
            mockWord("concept-a", category: .concepts, stack: "other-stack")
        ]
        let progress = mockProgress(stacks: ["test-stack"])

        let (selected, _) = service.selectQualifyingWords(
            from: words,
            startingAt: 0,
            userProgress: progress,
            count: 5
        )

        #expect(selected.isEmpty)
    }

    @Test("Returns empty array when input is empty")
    func returnsEmptyForEmptyInput() throws {
        let service = try makeService()
        let progress = mockProgress(stacks: ["test-stack"])

        let (selected, cursor) = service.selectQualifyingWords(
            from: [],
            startingAt: 0,
            userProgress: progress,
            count: 5
        )

        #expect(selected.isEmpty)
        #expect(cursor == 0)
    }

    @Test("Excludes mastered words from selection")
    func excludesMasteredWords() throws {
        let service = try makeService()
        let mastered = mockWord("concept-mastered", category: .concepts)
        let unmastered = mockWord("concept-fresh", category: .concepts)
        let words = [mastered, unmastered]

        let progress = mockProgress(stacks: ["test-stack"])
        progress.masteredWordIds = [mastered.id]

        let (selected, _) = service.selectQualifyingWords(
            from: words,
            startingAt: 0,
            userProgress: progress,
            count: 5
        )

        #expect(selected.count == 1)
        #expect(selected.first?.word == "concept-fresh")
    }

    @Test("Excludes words above user level")
    func excludesAdvancedWords() throws {
        let service = try makeService()
        let beginnerWord = mockWord("concept-easy", category: .concepts, level: 1)
        let advancedWord = mockWord("concept-hard", category: .concepts, level: 5)
        let words = [advancedWord, beginnerWord]

        let progress = mockProgress(stacks: ["test-stack"])
        progress.level = 1

        let (selected, _) = service.selectQualifyingWords(
            from: words,
            startingAt: 0,
            userProgress: progress,
            count: 5
        )

        #expect(selected.count == 1)
        #expect(selected.first?.word == "concept-easy")
    }

    @Test("Respects user's selectedStacks")
    func respectsSelectedStacks() throws {
        let service = try makeService()
        let inSelected = mockWord("concept-in", category: .concepts, stack: "selected-stack")
        let notSelected = mockWord("concept-out", category: .concepts, stack: "other-stack")
        let words = [inSelected, notSelected]

        let progress = mockProgress(stacks: ["selected-stack"])

        let (selected, _) = service.selectQualifyingWords(
            from: words,
            startingAt: 0,
            userProgress: progress,
            count: 5
        )

        #expect(selected.count == 1)
        #expect(selected.first?.word == "concept-in")
    }

    // MARK: - Result ordering

    @Test("Returns words ordered by category sequence")
    func wordsAreOrderedByCategorySequence() throws {
        let service = try makeService()
        // Insert in scrambled order
        let words = [
            mockWord("quality-a", category: .qualities),
            mockWord("concept-a", category: .concepts),
            mockWord("pattern-a", category: .patterns),
            mockWord("component-a", category: .components),
            mockWord("process-a", category: .processes)
        ]
        let progress = mockProgress(stacks: ["test-stack"])

        let (selected, _) = service.selectQualifyingWords(
            from: words,
            startingAt: 0,
            userProgress: progress,
            count: 5
        )

        // Expected order: concepts, components, processes, patterns, qualities
        #expect(selected[0].category == .concepts)
        #expect(selected[1].category == .components)
        #expect(selected[2].category == .processes)
        #expect(selected[3].category == .patterns)
        #expect(selected[4].category == .qualities)
    }

    // MARK: - Helpers

    private func makeService() throws -> WordService {
        let schema = Schema([Word.self, UserProgress.self, DailySet.self,
                             ReviewState.self, AssessmentResult.self, PracticedSentence.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return WordService(modelContext: container.mainContext)
    }

    private func mockWord(
        _ name: String,
        category: WordCategory,
        stack: String = "test-stack",
        level: Int = 1
    ) -> Word {
        Word(
            id: UUID(),
            word: name,
            pronunciation: "/\(name)/",
            partOfSpeech: "noun",
            shortDefinition: "Test",
            simpleDefinition: "Test",
            longDefinition: "Test",
            techContext: "Test",
            exampleSentence: "Test",
            etymology: "Test",
            connector: "Test",
            codeExampleLanguage: "swift",
            codeExampleCode: "let x = 1",
            stack: stack,
            unlockLevel: level,
            tags: [],
            category: category
        )
    }

    private func mockProgress(stacks: Set<String>, level: Int = 5) -> UserProgress {
        let progress = UserProgress()
        progress.level = level
        progress.selectedStacks = stacks
        return progress
    }
}

@Suite("WordCategory — schema compatibility")
struct WordCategoryTests {

    @Test("Raw values match the category names used in JSON files")
    func rawValuesMatchJSON() {
        #expect(WordCategory.concepts.rawValue == "concepts")
        #expect(WordCategory.components.rawValue == "components")
        #expect(WordCategory.processes.rawValue == "processes")
        #expect(WordCategory.patterns.rawValue == "patterns")
        #expect(WordCategory.qualities.rawValue == "qualities")
    }

    @Test("All 5 categories have unique emoji")
    func emojiAreUnique() {
        let emojis = [
            WordCategory.concepts.emoji,
            WordCategory.components.emoji,
            WordCategory.processes.emoji,
            WordCategory.patterns.emoji,
            WordCategory.qualities.emoji
        ]
        #expect(Set(emojis).count == 5)
    }
}

@Suite("WordDTO — backwards compatibility")
struct WordDTOTests {

    @Test("Defaults to concepts when category field absent")
    func defaultsToConceptsWhenMissing() throws {
        let json = """
        {
          "id": "test-001",
          "word": "test",
          "pronunciation": "TEST",
          "partOfSpeech": "noun",
          "shortDefinition": "test",
          "longDefinition": "test long",
          "unlockLevel": 1,
          "tags": []
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(WordDTO.self, from: json)
        #expect(dto.category == .concepts)
    }

    @Test("Decodes category field when present")
    func decodesExplicitCategory() throws {
        let json = """
        {
          "id": "test-001",
          "word": "stateless",
          "pronunciation": "STATE-less",
          "partOfSpeech": "adjective",
          "shortDefinition": "test",
          "longDefinition": "test long",
          "unlockLevel": 1,
          "tags": [],
          "category": "qualities"
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(WordDTO.self, from: json)
        #expect(dto.category == .qualities)
    }

    @Test("Defaults professionalContext to empty when absent")
    func professionalContextDefaultsEmpty() throws {
        let json = """
        {
          "id": "test-001",
          "word": "test",
          "pronunciation": "TEST",
          "partOfSpeech": "noun",
          "shortDefinition": "test",
          "longDefinition": "test long",
          "unlockLevel": 1,
          "tags": []
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(WordDTO.self, from: json)
        #expect(dto.professionalContext == "")
    }

    @Test("Decodes professionalContext for soft-skills words")
    func decodesProfessionalContext() throws {
        let json = """
        {
          "id": "comm-001",
          "word": "articulate",
          "pronunciation": "ar-TIK-yu-late",
          "partOfSpeech": "verb",
          "shortDefinition": "express clearly",
          "longDefinition": "long def",
          "professionalContext": "Senior engineers articulate trade-offs.",
          "unlockLevel": 1,
          "tags": ["communication"],
          "category": "processes"
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(WordDTO.self, from: json)
        #expect(dto.professionalContext == "Senior engineers articulate trade-offs.")
        #expect(dto.category == .processes)
    }

    @Test("Decodes soft-skills word without codeExample")
    func softSkillsWordWithoutCodeExample() throws {
        let json = """
        {
          "id": "comm-001",
          "word": "concise",
          "pronunciation": "kuhn-SAHYS",
          "partOfSpeech": "adjective",
          "shortDefinition": "brief",
          "longDefinition": "long def",
          "professionalContext": "test",
          "unlockLevel": 1,
          "tags": ["communication"],
          "category": "qualities"
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(WordDTO.self, from: json)
        #expect(dto.codeExample == nil)
        #expect(dto.word == "concise")
    }
}
