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

        // Add enough correct assessments to jump multiple levels.
        // Thresholds (LevelDefinition): L1→L2 = 15, L2→L3 = 35, L3→L4 = 60, L4→L5 = 90.
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

        // 60 words assessed correctly twice clears L1→L2 (15), L2→L3 (35), and
        // L3→L4 (60), but not L4→L5 (90), so the user lands on level 4.
        let newLevel = try service.recordAssessmentResult(
            wordId: UUID(),
            isCorrect: true,
            selectedAnswer: "test",
            correctAnswer: "test",
            userProgress: userProgress
        )

        #expect(userProgress.level == 4)
        #expect(newLevel == 4)
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
