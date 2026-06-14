import Testing
import Foundation
@testable import StackSpeak

@Suite("ProgressSnapshot — cross-platform contract")
struct ProgressSnapshotTests {

    private func sample() -> ProgressSnapshot {
        ProgressSnapshot(
            schemaVersion: ProgressSnapshot.currentSchemaVersion,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            level: 7,
            currentStreak: 3,
            longestStreak: 9,
            lastCompletedDate: Date(timeIntervalSince1970: 1_699_990_000),
            didCompleteOnboarding: true,
            practicedWordIds: ["a", "b"],
            masteredWordIds: ["a"],
            bookmarkedWordIds: [],
            wordsWithTwoCorrectIds: ["a"],
            wordsCreditedForLevelIds: ["a", "b"],
            selectedStacks: ["api-basic", "git-basic"],
            shuffleSeed: UUID().uuidString,
            wordQueueCursor: 12,
            reviewStates: [.init(wordId: "a", easinessFactor: 2.5, interval: 6,
                                 repetitions: 2, dueDate: Date(timeIntervalSince1970: 1_700_500_000),
                                 lastReviewedAt: nil)],
            assessmentResults: [.init(id: "r1", wordId: "a",
                                      attemptedAt: Date(timeIntervalSince1970: 1_699_000_000),
                                      isCorrect: true, selectedAnswer: "x", correctAnswer: "x")],
            practicedSentences: [.init(wordId: "a", sentence: "Used it well.",
                                       createdAt: Date(timeIntervalSince1970: 1_699_000_000),
                                       inputMethod: "typed")],
            bookProgress: [.init(bookId: "100-things-programmer",
                                 lastOpenedAt: Date(timeIntervalSince1970: 1_699_000_000),
                                 currentChapterId: "ch1", currentCardId: "c3",
                                 completedCardIds: ["c1", "c2"], lastReadingDayString: "2026-06-13",
                                 currentStreakDays: 2, longestStreakDays: 5)]
        )
    }

    @Test("Snapshot round-trips through the sync JSON encoder/decoder")
    func roundTrips() throws {
        let original = sample()
        let data = try SupabaseBackendService.encode(original)
        let restored = try SupabaseBackendService.decode(ProgressSnapshot.self, from: data)
        #expect(restored == original)
    }

    @Test("UserProgress.makeSnapshot captures core progress")
    func mapsFromUserProgress() {
        let p = UserProgress()
        p.level = 5
        p.currentStreak = 4
        p.didCompleteOnboarding = true
        let snap = p.makeSnapshot(bookProgress: [], now: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(snap.level == 5)
        #expect(snap.currentStreak == 4)
        #expect(snap.didCompleteOnboarding == true)
        #expect(snap.schemaVersion == ProgressSnapshot.currentSchemaVersion)
        // Entitlement must NOT leak into the synced record (no such fields exist).
        #expect(snap.selectedStacks.isEmpty == false)  // defaults to mandatory stacks
    }
}
