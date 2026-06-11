import Testing
import Foundation
import SwiftData
@testable import StackSpeak

@Suite("ProgressService Tests")
@MainActor
struct ProgressServiceTests {

    /// Returns the in-memory container; the caller MUST keep it alive for the test's
    /// duration. Its `mainContext` is owned by the container, so returning only the
    /// context would let ARC deallocate the container and dangle the context.
    /// SwiftData auto-includes UserProgress's cascade targets (AssessmentResult,
    /// ReviewState, PracticedSentence) from the relationship graph.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: UserProgress.self, DailySet.self,
            configurations: config
        )
    }

    @Test("Multi-level advancement uses the two-correct currency")
    func testMultiLevelAdvancement() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = ProgressService(modelContext: context)
        let userProgress = UserProgress()
        userProgress.level = 1
        context.insert(userProgress)

        // Seed 34 distinct words each answered correctly twice (the level
        // currency), plus one word with a single correct (in-progress).
        let pendingWord = UUID()
        for _ in 0..<34 {
            let wordId = UUID()
            for _ in 0..<2 {
                userProgress.assessmentResults.append(AssessmentResult(
                    wordId: wordId, attemptedAt: Date(), isCorrect: true,
                    selectedAnswer: "c", correctAnswer: "c"))
            }
        }
        userProgress.assessmentResults.append(AssessmentResult(
            wordId: pendingWord, attemptedAt: Date(), isCorrect: true,
            selectedAnswer: "c", correctAnswer: "c"))
        userProgress.rebuildProgressCaches()
        #expect(userProgress.wordsAssessedForLevel == 34)

        // The pending word's second correct makes it the 35th credited word,
        // crossing every threshold up to Engineer I (L11, requires 35).
        // L12 requires 40, so it stops at 11.
        let newLevel = try service.recordAssessmentResult(
            wordId: pendingWord, isCorrect: true,
            selectedAnswer: "c", correctAnswer: "c",
            userProgress: userProgress
        )

        #expect(userProgress.wordsAssessedForLevel == 35)
        #expect(userProgress.level == 11)
        #expect(newLevel == 11)
    }

    @Test("First correct is in-progress; the second correct credits the level")
    func testSecondCorrectCredits() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = ProgressService(modelContext: context)
        let userProgress = UserProgress()
        context.insert(userProgress)
        let word = UUID()

        _ = try service.recordAssessmentResult(
            wordId: word, isCorrect: true, selectedAnswer: "c", correctAnswer: "c",
            userProgress: userProgress)
        #expect(userProgress.wordsAssessedForLevel == 0)        // in-progress, no credit yet
        #expect(userProgress.wordsCreditedForLevelIds.contains(word))

        _ = try service.recordAssessmentResult(
            wordId: word, isCorrect: true, selectedAnswer: "c", correctAnswer: "c",
            userProgress: userProgress)
        #expect(userProgress.wordsAssessedForLevel == 1)        // credited on the second correct
        #expect(userProgress.wordsAssessedCorrectlyTwice == 1)

        // A third correct doesn't double-count the word.
        _ = try service.recordAssessmentResult(
            wordId: word, isCorrect: true, selectedAnswer: "c", correctAnswer: "c",
            userProgress: userProgress)
        #expect(userProgress.wordsAssessedForLevel == 1)
    }

    @Test("Skip/report marks mastered but grants no level credit")
    func testSkipDoesNotLevel() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = ProgressService(modelContext: context)
        let userProgress = UserProgress()
        context.insert(userProgress)
        let word = UUID()

        try service.markWordPracticed(
            wordId: word, sentence: "", inputMethod: .typed,
            markAsMastered: true, userProgress: userProgress)

        #expect(userProgress.masteredWordIds.contains(word))
        #expect(userProgress.wordsAssessedForLevel == 0)
        #expect(userProgress.level == 1)
    }

    @Test("Streak calculation handles consecutive days")
    func testStreakConsecutiveDays() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserProgress.self, DailySet.self,
            configurations: config
        )
        let context = container.mainContext
        let service = ProgressService(modelContext: context)

        let userProgress = UserProgress()
        context.insert(userProgress)

        // First completion
        let wordId1 = UUID()
        let dailySet1 = DailySet(
            dayString: "2026-01-01",
            wordIds: [wordId1]
        )
        dailySet1.markWordCompleted(wordId1)
        context.insert(dailySet1)

        userProgress.currentStreak = 0
        userProgress.lastCompletedDate = nil
        try service.completeDailySet(dailySet1, userProgress: userProgress)

        #expect(userProgress.currentStreak == 1)

        // Complete next day (consecutive)
        userProgress.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        let wordId2 = UUID()
        let dailySet2 = DailySet(
            dayString: DailySet.todayString(),
            wordIds: [wordId2]
        )
        dailySet2.markWordCompleted(wordId2)
        context.insert(dailySet2)

        try service.completeDailySet(dailySet2, userProgress: userProgress)

        #expect(userProgress.currentStreak == 2)
    }

    @Test("Streak resets after gap")
    func testStreakResetsAfterGap() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserProgress.self, DailySet.self,
            configurations: config
        )
        let context = container.mainContext
        let service = ProgressService(modelContext: context)

        let userProgress = UserProgress()
        context.insert(userProgress)

        userProgress.currentStreak = 5
        userProgress.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())

        let gapWordId = UUID()
        let dailySet = DailySet(
            dayString: DailySet.todayString(),
            wordIds: [gapWordId]
        )
        dailySet.markWordCompleted(gapWordId)
        context.insert(dailySet)

        try service.completeDailySet(dailySet, userProgress: userProgress)

        // Streak should reset to 1 after a gap
        #expect(userProgress.currentStreak == 1)
    }

    @Test("Longest streak tracks maximum")
    func testLongestStreakTracking() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserProgress.self, DailySet.self,
            configurations: config
        )
        let context = container.mainContext
        let service = ProgressService(modelContext: context)

        let userProgress = UserProgress()
        context.insert(userProgress)

        userProgress.currentStreak = 10
        userProgress.longestStreak = 5
        userProgress.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())

        let longestWordId = UUID()
        let dailySet = DailySet(
            dayString: DailySet.todayString(),
            wordIds: [longestWordId]
        )
        dailySet.markWordCompleted(longestWordId)
        context.insert(dailySet)

        try service.completeDailySet(dailySet, userProgress: userProgress)

        // Longest should update to current if current is higher
        #expect(userProgress.longestStreak == 11)
    }

    @Test("recordWordCompletion finishes the day only on the final base word")
    func testRecordWordCompletionGate() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = ProgressService(modelContext: context)

        let userProgress = UserProgress()
        context.insert(userProgress)

        let wordIds = (0..<5).map { _ in UUID() }
        let dailySet = DailySet(dayString: DailySet.todayString(), wordIds: wordIds)
        context.insert(dailySet)

        // Words 1-4: day must not complete, no streak credit.
        for id in wordIds.prefix(4) {
            let dayComplete = try service.recordWordCompletion(
                wordId: id, sentence: "explanation", inputMethod: .typed,
                markAsMastered: false, dailySet: dailySet, userProgress: userProgress)
            #expect(dayComplete == false)
        }
        #expect(userProgress.currentStreak == 0)
        #expect(userProgress.lastCompletedDate == nil)

        // 5th word: day completes, streak credited.
        let dayComplete = try service.recordWordCompletion(
            wordId: wordIds[4], sentence: "explanation", inputMethod: .typed,
            markAsMastered: false, dailySet: dailySet, userProgress: userProgress)
        #expect(dayComplete == true)
        #expect(userProgress.currentStreak == 1)
        #expect(userProgress.lastCompletedDate != nil)
    }

    @Test("Streak break does not drop level")
    func testStreakBreakKeepsLevel() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = ProgressService(modelContext: context)

        let userProgress = UserProgress()
        context.insert(userProgress)

        userProgress.level = 7
        userProgress.currentStreak = 12
        // Simulate a 4-day gap — a broken streak.
        userProgress.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -4, to: Date())

        let wordId = UUID()
        let dailySet = DailySet(dayString: DailySet.todayString(), wordIds: [wordId])
        dailySet.markWordCompleted(wordId)
        context.insert(dailySet)

        try service.completeDailySet(dailySet, userProgress: userProgress)

        #expect(userProgress.currentStreak == 1)  // streak reset by the gap
        #expect(userProgress.level == 7)          // level must never drop
    }
}
