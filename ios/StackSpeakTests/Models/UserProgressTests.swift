import Testing
import Foundation
@testable import StackSpeak

/// `canAttemptAssessment` enforces one attempt per word per calendar day —
/// correct or wrong. The second (final) correct attempt must happen on a
/// different day.
@Suite("UserProgress — assessment cooldown")
struct AssessmentCooldownTests {

    @Test("No prior attempts — always eligible")
    func noAttemptsAlwaysEligible() {
        let progress = UserProgress()
        #expect(progress.canAttemptAssessment(for: UUID()))
    }

    @Test("Attempted today (correct) — not eligible until tomorrow")
    func correctTodayBlocksToday() {
        let progress = UserProgress()
        let wordId = UUID()
        progress.assessmentResults.append(AssessmentResult(
            wordId: wordId,
            attemptedAt: Date(),
            isCorrect: true,
            selectedAnswer: "correct",
            correctAnswer: "correct"
        ))
        #expect(!progress.canAttemptAssessment(for: wordId))
    }

    @Test("Attempted today (wrong) — not eligible until tomorrow")
    func wrongTodayBlocksToday() {
        let progress = UserProgress()
        let wordId = UUID()
        progress.assessmentResults.append(AssessmentResult(
            wordId: wordId,
            attemptedAt: Date(),
            isCorrect: false,
            selectedAnswer: "wrong",
            correctAnswer: "right"
        ))
        #expect(!progress.canAttemptAssessment(for: wordId))
    }

    @Test("Last attempt was yesterday — eligible")
    func attemptYesterdayIsEligible() {
        let progress = UserProgress()
        let wordId = UUID()
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else {
            Issue.record("Could not compute yesterday's date")
            return
        }
        progress.assessmentResults.append(AssessmentResult(
            wordId: wordId,
            attemptedAt: yesterday,
            isCorrect: false,
            selectedAnswer: "wrong",
            correctAnswer: "right"
        ))
        #expect(progress.canAttemptAssessment(for: wordId))
    }

    @Test("Cooldown is per-word — other words remain eligible")
    func cooldownIsPerWord() {
        let progress = UserProgress()
        let blocked = UUID()
        let other = UUID()
        progress.assessmentResults.append(AssessmentResult(
            wordId: blocked,
            attemptedAt: Date(),
            isCorrect: true,
            selectedAnswer: "a",
            correctAnswer: "a"
        ))
        #expect(!progress.canAttemptAssessment(for: blocked))
        #expect(progress.canAttemptAssessment(for: other))
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
