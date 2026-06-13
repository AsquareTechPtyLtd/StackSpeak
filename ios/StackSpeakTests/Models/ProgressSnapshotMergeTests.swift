import Testing
import Foundation
@testable import StackSpeak

@Suite("ProgressSnapshot.merge — additive, never loses progress")
struct ProgressSnapshotMergeTests {

    private func base(updatedAt: Date = Date(timeIntervalSince1970: 1000)) -> ProgressSnapshot {
        ProgressSnapshot(
            schemaVersion: 1, updatedAt: updatedAt,
            level: 1, currentStreak: 0, longestStreak: 0, lastCompletedDate: nil,
            didCompleteOnboarding: false,
            practicedWordIds: [], masteredWordIds: [], bookmarkedWordIds: [],
            wordsWithTwoCorrectIds: [], wordsCreditedForLevelIds: [],
            selectedStacks: [], shuffleSeed: "seed", wordQueueCursor: 0,
            reviewStates: [], assessmentResults: [], practicedSentences: [], bookProgress: []
        )
    }

    @Test("Monotonic word-id sets are unioned; preference sets are last-write-wins")
    func unionsSets() {
        var a = base(); a.masteredWordIds = ["w1", "w2"]; a.bookmarkedWordIds = ["b1"]
        var b = base(); b.masteredWordIds = ["w2", "w3"]; b.bookmarkedWordIds = ["b2"]
        let m = ProgressSnapshot.merge(local: a, remote: b)
        // Monotonic sets (mastered progress) always union — never drop a word.
        #expect(m.masteredWordIds == ["w1", "w2", "w3"])
        // Bookmarks are a preference: union would reverse intentional un-bookmarking.
        // When updatedAt ties, local wins (a.updatedAt >= b.updatedAt), so we get a's bookmarks.
        #expect(m.bookmarkedWordIds == ["b1"])
    }

    @Test("Un-bookmarking on the newer device is honoured")
    func bookmarkLastWriteWins() {
        var a = base(updatedAt: Date(timeIntervalSince1970: 2000))
        a.bookmarkedWordIds = ["b1", "b2"]
        var b = base(updatedAt: Date(timeIntervalSince1970: 3000))
        b.bookmarkedWordIds = ["b1"]   // user un-bookmarked b2 on the newer device
        let m = ProgressSnapshot.merge(local: a, remote: b)
        // Newer device (b) wins — b2 should be gone, not resurrected by union.
        #expect(m.bookmarkedWordIds == ["b1"])
    }

    @Test("Stack deselection on the newer device is honoured")
    func stackDeselectionLastWriteWins() {
        var a = base(updatedAt: Date(timeIntervalSince1970: 1000))
        a.selectedStacks = ["api-basic", "gcp-basic"]
        var b = base(updatedAt: Date(timeIntervalSince1970: 2000))
        b.selectedStacks = ["api-basic"]   // user deselected gcp-basic on the newer device
        let m = ProgressSnapshot.merge(local: a, remote: b)
        // Newer device (b) wins — gcp-basic should be gone, not resurrected by union.
        #expect(m.selectedStacks == ["api-basic"])
    }

    @Test("Level and longest streak take the maximum; cursor paired with seed from newerByUpdate")
    func maxCounters() {
        var a = base(); a.level = 8; a.longestStreak = 12; a.wordQueueCursor = 30
        var b = base(); b.level = 5; b.longestStreak = 20; b.wordQueueCursor = 10
        let m = ProgressSnapshot.merge(local: a, remote: b)
        #expect(m.level == 8)
        #expect(m.longestStreak == 20)
        // Both snapshots have equal updatedAt, so local (a) wins for newerByUpdate.
        // wordQueueCursor comes from newerByUpdate (a) = 30; same result as max() here.
        #expect(m.wordQueueCursor == 30)
    }

    @Test("wordQueueCursor stays paired with its shuffleSeed (newer side wins both)")
    func cursorAndSeedPaired() {
        var a = base(updatedAt: Date(timeIntervalSince1970: 1000))
        a.shuffleSeed = "SEED-A"; a.wordQueueCursor = 5
        var b = base(updatedAt: Date(timeIntervalSince1970: 2000))
        b.shuffleSeed = "SEED-B"; b.wordQueueCursor = 3
        let m = ProgressSnapshot.merge(local: a, remote: b)
        // Newer side (b) should provide BOTH seed and cursor so they remain consistent.
        #expect(m.shuffleSeed == "SEED-B")
        #expect(m.wordQueueCursor == 3)
    }

    @Test("Current streak follows the most recently completed device")
    func currentStreakFromRecentSide() {
        var a = base(); a.currentStreak = 3; a.lastCompletedDate = Date(timeIntervalSince1970: 5000)
        var b = base(); b.currentStreak = 7; b.lastCompletedDate = Date(timeIntervalSince1970: 9000)
        let m = ProgressSnapshot.merge(local: a, remote: b)
        #expect(m.currentStreak == 7)   // b completed more recently
        #expect(m.lastCompletedDate == Date(timeIntervalSince1970: 9000))
    }

    @Test("Onboarding completion is sticky (true if either side finished)")
    func onboardingOr() {
        var a = base(); a.didCompleteOnboarding = false
        var b = base(); b.didCompleteOnboarding = true
        #expect(ProgressSnapshot.merge(local: a, remote: b).didCompleteOnboarding == true)
    }

    @Test("Per-word SRS keeps the most recently reviewed state")
    func reviewStateKeepsLatest() {
        var a = base()
        a.reviewStates = [.init(wordId: "w1", easinessFactor: 2.5, interval: 1, repetitions: 1,
                                dueDate: Date(timeIntervalSince1970: 2000),
                                lastReviewedAt: Date(timeIntervalSince1970: 1000))]
        var b = base()
        b.reviewStates = [.init(wordId: "w1", easinessFactor: 2.6, interval: 6, repetitions: 2,
                                dueDate: Date(timeIntervalSince1970: 8000),
                                lastReviewedAt: Date(timeIntervalSince1970: 5000))]
        let m = ProgressSnapshot.merge(local: a, remote: b)
        #expect(m.reviewStates.count == 1)
        #expect(m.reviewStates[0].repetitions == 2)   // b reviewed later
    }

    @Test("Assessment results union by id; sentences dedupe")
    func resultsAndSentences() {
        var a = base()
        a.assessmentResults = [.init(id: "r1", wordId: "w1", attemptedAt: Date(timeIntervalSince1970: 1),
                                     isCorrect: true, selectedAnswer: "x", correctAnswer: "x")]
        a.practicedSentences = [.init(wordId: "w1", sentence: "Hi", createdAt: Date(timeIntervalSince1970: 1), inputMethod: "typed")]
        var b = base()
        b.assessmentResults = [.init(id: "r1", wordId: "w1", attemptedAt: Date(timeIntervalSince1970: 1),
                                     isCorrect: true, selectedAnswer: "x", correctAnswer: "x"),   // dup id
                               .init(id: "r2", wordId: "w2", attemptedAt: Date(timeIntervalSince1970: 2),
                                     isCorrect: false, selectedAnswer: "y", correctAnswer: "z")]
        b.practicedSentences = a.practicedSentences  // identical → dedupe to one
        let m = ProgressSnapshot.merge(local: a, remote: b)
        #expect(m.assessmentResults.count == 2)
        #expect(m.practicedSentences.count == 1)
    }

    @Test("Book progress unions completed cards and maxes streaks")
    func bookMerge() {
        var a = base()
        a.bookProgress = [.init(bookId: "bk", lastOpenedAt: Date(timeIntervalSince1970: 1000),
                                currentChapterId: "c1", currentCardId: "card1",
                                completedCardIds: ["x1"], lastReadingDayString: "2026-06-10",
                                currentStreakDays: 2, longestStreakDays: 4)]
        var b = base()
        b.bookProgress = [.init(bookId: "bk", lastOpenedAt: Date(timeIntervalSince1970: 9000),
                                currentChapterId: "c2", currentCardId: "card9",
                                completedCardIds: ["x2"], lastReadingDayString: "2026-06-13",
                                currentStreakDays: 5, longestStreakDays: 3)]
        let m = ProgressSnapshot.merge(local: a, remote: b)
        #expect(m.bookProgress.count == 1)
        #expect(m.bookProgress[0].completedCardIds == ["x1", "x2"])
        #expect(m.bookProgress[0].longestStreakDays == 4)
        #expect(m.bookProgress[0].currentCardId == "card9")   // b opened more recently
    }
}
