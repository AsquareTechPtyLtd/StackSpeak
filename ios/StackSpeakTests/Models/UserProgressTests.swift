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

    @Test("Wrong answer — blocked during the retry cooldown")
    func wrongWithinCooldownBlocks() {
        let progress = UserProgress()
        let wordId = UUID()
        let now = Date()
        progress.assessmentResults.append(AssessmentResult(
            wordId: wordId,
            attemptedAt: now,
            isCorrect: false,
            selectedAnswer: "wrong",
            correctAnswer: "right"
        ))
        // 5 minutes later — still inside the 15-minute cooldown.
        #expect(!progress.canAttemptAssessment(for: wordId, now: now.addingTimeInterval(5 * 60)))
    }

    @Test("Wrong answer — retryable same session once the cooldown elapses")
    func wrongAfterCooldownIsEligibleSameDay() {
        let progress = UserProgress()
        let wordId = UUID()
        let now = Date()
        progress.assessmentResults.append(AssessmentResult(
            wordId: wordId,
            attemptedAt: now,
            isCorrect: false,
            selectedAnswer: "wrong",
            correctAnswer: "right"
        ))
        // 16 minutes later — cooldown elapsed, same calendar day. No full-day lockout.
        let later = now.addingTimeInterval(16 * 60)
        #expect(progress.canAttemptAssessment(for: wordId, now: later))
        #expect(Calendar.current.isDate(later, inSameDayAs: now))
    }

    @Test("Correct answer — still spaced to a different day (retention)")
    func correctSpacedToNextDay() {
        let progress = UserProgress()
        let wordId = UUID()
        let now = Date()
        progress.assessmentResults.append(AssessmentResult(
            wordId: wordId,
            attemptedAt: now,
            isCorrect: true,
            selectedAnswer: "a",
            correctAnswer: "a"
        ))
        // Even hours later (same day), the second correct answer is not yet allowed.
        #expect(!progress.canAttemptAssessment(for: wordId, now: now.addingTimeInterval(6 * 3600)))
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

    // Calendar arithmetic, not raw TimeInterval offsets: "-24h" is not always
    // "yesterday" (DST transitions; running exactly at midnight), and "-48h"
    // can resolve to 1 calendar day across a fall-back night. The production
    // code compares startOfDay values, so the fixtures must too.
    @Test("Completed yesterday — shows current streak (still valid)")
    func completedYesterdayShowsStreak() {
        let progress = UserProgress()
        progress.currentStreak = 4
        progress.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        #expect(progress.displayedCurrentStreak == 4)
    }

    @Test("Completed 2+ days ago — streak broken, shows 0")
    func completedTwoDaysAgoShowsZero() {
        let progress = UserProgress()
        progress.currentStreak = 7
        progress.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        #expect(progress.displayedCurrentStreak == 0)
    }

    @Test("Midnight edge: exactly yesterday vs exactly 2 days ago via injected clock")
    func midnightEdgeWithInjectedClock() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        // Fixed "now" one second after midnight — the worst case for raw-offset math.
        let now = Date(timeIntervalSince1970: 1_750_000_000 - (1_750_000_000 % 86_400) + 1)

        let progress = UserProgress()
        progress.currentStreak = 5

        progress.lastCompletedDate = calendar.date(byAdding: .day, value: -1, to: now)
        #expect(progress.displayedCurrentStreak(now: now, calendar: calendar) == 5)

        progress.lastCompletedDate = calendar.date(byAdding: .day, value: -2, to: now)
        #expect(progress.displayedCurrentStreak(now: now, calendar: calendar) == 0)
    }
}

@Suite("UserProgress — progress caches")
struct ProgressCacheTests {

    @Test("rebuildProgressCaches splits credited (≥1) from two-correct (≥2)")
    func rebuildMatchesRawScan() {
        let progress = UserProgress()
        let wordA = UUID()
        let wordB = UUID()

        // wordA gets 2 correct
        progress.assessmentResults.append(AssessmentResult(wordId: wordA, attemptedAt: Date(), isCorrect: true, selectedAnswer: "a", correctAnswer: "a"))
        progress.assessmentResults.append(AssessmentResult(wordId: wordA, attemptedAt: Date(), isCorrect: true, selectedAnswer: "a", correctAnswer: "a"))
        // wordB gets 1 correct
        progress.assessmentResults.append(AssessmentResult(wordId: wordB, attemptedAt: Date(), isCorrect: true, selectedAnswer: "b", correctAnswer: "b"))

        progress.rebuildProgressCaches()

        // credited (level currency): both words count
        #expect(progress.wordsCreditedForLevelIds.contains(wordA))
        #expect(progress.wordsCreditedForLevelIds.contains(wordB))
        #expect(progress.wordsAssessedForLevel == 2)

        // retention stat: only the twice-correct word
        #expect(progress.wordsWithTwoCorrectIds.contains(wordA))
        #expect(!progress.wordsWithTwoCorrectIds.contains(wordB))
        #expect(progress.wordsAssessedCorrectlyTwice == 1)
    }
}
