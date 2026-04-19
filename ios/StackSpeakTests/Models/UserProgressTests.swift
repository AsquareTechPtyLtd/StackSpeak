import Testing
import Foundation
@testable import StackSpeak

@Suite("UserProgress — assessment cooldown")
struct AssessmentCooldownTests {

    @Test("No prior attempts — always eligible")
    func noAttemptsAlwaysEligible() {
        let progress = UserProgress()
        #expect(progress.canAttemptAssessment(for: UUID()))
    }

    @Test("After correct answer — immediately eligible again")
    func afterCorrectImmediatelyEligible() {
        let progress = UserProgress()
        let wordId = UUID()
        let result = AssessmentResult(
            wordId: wordId,
            attemptedAt: Date(),
            isCorrect: true,
            selectedAnswer: "correct",
            correctAnswer: "correct"
        )
        progress.assessmentResults.append(result)
        #expect(progress.canAttemptAssessment(for: wordId))
    }

    @Test("After wrong answer less than 24h ago — not eligible")
    func afterWrongAnswerWithin24h() {
        let progress = UserProgress()
        let wordId = UUID()
        let twelveHoursAgo = Date().addingTimeInterval(-12 * 3600)
        let result = AssessmentResult(
            wordId: wordId,
            attemptedAt: twelveHoursAgo,
            isCorrect: false,
            selectedAnswer: "wrong",
            correctAnswer: "right"
        )
        progress.assessmentResults.append(result)
        #expect(!progress.canAttemptAssessment(for: wordId))
    }

    @Test("After wrong answer more than 24h ago — eligible")
    func afterWrongAnswerAfter24h() {
        let progress = UserProgress()
        let wordId = UUID()
        let twentyFiveHoursAgo = Date().addingTimeInterval(-25 * 3600)
        let result = AssessmentResult(
            wordId: wordId,
            attemptedAt: twentyFiveHoursAgo,
            isCorrect: false,
            selectedAnswer: "wrong",
            correctAnswer: "right"
        )
        progress.assessmentResults.append(result)
        #expect(progress.canAttemptAssessment(for: wordId))
    }
}

@Suite("UserProgress — streak display")
struct StreakDisplayTests {

    @Test("No last completed date — streak is 0")
    func noCompletedDateShowsZero() {
        let progress = UserProgress()
        progress.currentStreak = 5
        #expect(progress.displayedCurrentStreak == 0)
    }

    @Test("Completed today — shows current streak")
    func completedTodayShowsStreak() {
        let progress = UserProgress()
        progress.currentStreak = 3
        progress.lastCompletedDate = Date()
        #expect(progress.displayedCurrentStreak == 3)
    }

    @Test("Completed yesterday — shows current streak (still valid)")
    func completedYesterdayShowsStreak() {
        let progress = UserProgress()
        progress.currentStreak = 4
        progress.lastCompletedDate = Date().addingTimeInterval(-24 * 3600)
        #expect(progress.displayedCurrentStreak == 4)
    }

    @Test("Completed 2+ days ago — streak broken, shows 0")
    func completedTwoDaysAgoShowsZero() {
        let progress = UserProgress()
        progress.currentStreak = 7
        progress.lastCompletedDate = Date().addingTimeInterval(-48 * 3600)
        #expect(progress.displayedCurrentStreak == 0)
    }
}

@Suite("UserProgress — wordsWithTwoCorrect cache")
struct TwoCorrectCacheTests {

    @Test("rebuildTwoCorrectCache is consistent with raw results")
    func rebuildMatchesRawScan() {
        let progress = UserProgress()
        let wordA = UUID()
        let wordB = UUID()

        // wordA gets 2 correct
        progress.assessmentResults.append(AssessmentResult(wordId: wordA, attemptedAt: Date(), isCorrect: true, selectedAnswer: "a", correctAnswer: "a"))
        progress.assessmentResults.append(AssessmentResult(wordId: wordA, attemptedAt: Date(), isCorrect: true, selectedAnswer: "a", correctAnswer: "a"))
        // wordB gets 1 correct
        progress.assessmentResults.append(AssessmentResult(wordId: wordB, attemptedAt: Date(), isCorrect: true, selectedAnswer: "b", correctAnswer: "b"))

        progress.rebuildTwoCorrectCache()

        #expect(progress.wordsWithTwoCorrectIds.contains(wordA))
        #expect(!progress.wordsWithTwoCorrectIds.contains(wordB))
        #expect(progress.wordsAssessedCorrectlyTwice == 1)
    }
}
