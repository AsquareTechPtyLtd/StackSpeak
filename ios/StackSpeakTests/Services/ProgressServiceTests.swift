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

    @Test("Multi-level advancement uses the credited (first-correct) currency")
    func testMultiLevelAdvancement() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = ProgressService(modelContext: context)
        let userProgress = UserProgress()
        userProgress.level = 1
        context.insert(userProgress)

        // Seed 34 distinct words each credited once (first correct = level currency).
        for _ in 0..<34 {
            userProgress.assessmentResults.append(AssessmentResult(
                wordId: UUID(), attemptedAt: Date(), isCorrect: true,
                selectedAnswer: "c", correctAnswer: "c"))
        }
        userProgress.rebuildProgressCaches()
        #expect(userProgress.wordsAssessedForLevel == 34)

        // Recording the 35th credited word crosses every threshold up to
        // Engineer I (L11, requires 35). L12 requires 40, so it stops at 11.
        let newLevel = try service.recordAssessmentResult(
            wordId: UUID(), isCorrect: true,
            selectedAnswer: "c", correctAnswer: "c",
            userProgress: userProgress
        )

        #expect(userProgress.wordsAssessedForLevel == 35)
        #expect(userProgress.level == 11)
        #expect(newLevel == 11)
    }

    @Test("First correct credits the level; second correct is retention only")
    func testFirstCorrectCredits() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = ProgressService(modelContext: context)
        let userProgress = UserProgress()
        context.insert(userProgress)
        let word = UUID()

        _ = try service.recordAssessmentResult(
            wordId: word, isCorrect: true, selectedAnswer: "c", correctAnswer: "c",
            userProgress: userProgress)
        #expect(userProgress.wordsAssessedForLevel == 1)        // credited immediately
        #expect(userProgress.wordsAssessedCorrectlyTwice == 0)  // not yet retained

        _ = try service.recordAssessmentResult(
            wordId: word, isCorrect: true, selectedAnswer: "c", correctAnswer: "c",
            userProgress: userProgress)
        #expect(userProgress.wordsAssessedForLevel == 1)        // still one credited word
        #expect(userProgress.wordsAssessedCorrectlyTwice == 1)  // now retained
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
}
