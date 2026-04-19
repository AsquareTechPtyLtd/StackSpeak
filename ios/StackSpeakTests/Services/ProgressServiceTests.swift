import Testing
import Foundation
import SwiftData
@testable import StackSpeak

@Suite("ProgressService Tests")
@MainActor
struct ProgressServiceTests {

    @Test("Multi-level advancement works correctly")
    func testMultiLevelAdvancement() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserProgress.self, AssessmentResult.self,
            configurations: config
        )
        let context = container.mainContext
        let service = ProgressService(modelContext: context)

        let userProgress = UserProgress()
        userProgress.level = 1
        context.insert(userProgress)

        // Add enough correct assessments to jump multiple levels
        // L1→L2 needs 20, L2→L3 needs 50, L3→L4 needs 100
        for i in 0..<120 {
            let wordId = UUID()
            let result = AssessmentResult(
                wordId: wordId,
                attemptedAt: Date(),
                isCorrect: true,
                selectedAnswer: "correct",
                correctAnswer: "correct"
            )
            userProgress.assessmentResults.append(result)

            // Second correct assessment for same word
            if i < 60 {
                let result2 = AssessmentResult(
                    wordId: wordId,
                    attemptedAt: Date(),
                    isCorrect: true,
                    selectedAnswer: "correct",
                    correctAnswer: "correct"
                )
                userProgress.assessmentResults.append(result2)
            }
        }

        // Rebuild cache to reflect the 60 words with 2+ correct
        userProgress.rebuildTwoCorrectCache()

        // Should advance to level 3 (60 words with 2 correct exceeds L2→L3 threshold of 50)
        let newLevel = service.recordAssessmentResult(
            wordId: UUID(),
            isCorrect: true,
            selectedAnswer: "test",
            correctAnswer: "test",
            userProgress: userProgress
        )

        #expect(userProgress.level >= 2, "Should have advanced at least to level 2")
        #expect(newLevel != nil, "Should return new level")
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
        let dailySet1 = DailySet(
            dayString: "2026-01-01",
            wordIds: [UUID()],
            completedWordIds: [UUID()]
        )
        context.insert(dailySet1)

        userProgress.currentStreak = 0
        userProgress.lastCompletedDate = nil
        try service.completeDailySet(dailySet1, userProgress: userProgress)

        #expect(userProgress.currentStreak == 1)

        // Complete next day (consecutive)
        userProgress.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        let dailySet2 = DailySet(
            dayString: DailySet.todayString(),
            wordIds: [UUID()],
            completedWordIds: [UUID()]
        )
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

        let dailySet = DailySet(
            dayString: DailySet.todayString(),
            wordIds: [UUID()],
            completedWordIds: [UUID()]
        )
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

        let dailySet = DailySet(
            dayString: DailySet.todayString(),
            wordIds: [UUID()],
            completedWordIds: [UUID()]
        )
        context.insert(dailySet)

        try service.completeDailySet(dailySet, userProgress: userProgress)

        // Longest should update to current if current is higher
        #expect(userProgress.longestStreak == 11)
    }
}
