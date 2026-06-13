import Foundation
@testable import StackSpeak

// Representative `ProgressSnapshot` values used by the fixture generator. Built
// with the memberwise init (uppercase `.uuidString` ids, sorted, fixed dates) so
// the encoded files are the canonical iOS-shaped contract Android must match.
enum SnapshotFixtures {

    private static func uid(_ mnemonic: String) -> String { deterministicUUID(from: mnemonic).uuidString }
    private static let seed = UUID(uuidString: "ABCDEF01-2345-6789-ABCD-EF0123456789")!

    typealias Review = ProgressSnapshot.ReviewStateDTO
    typealias Assessment = ProgressSnapshot.AssessmentResultDTO
    typealias Sentence = ProgressSnapshot.PracticedSentenceDTO
    typealias Book = ProgressSnapshot.BookProgressDTO

    /// Fresh install: empty sets, nil optional dates, onboarding incomplete.
    static let newUser = ProgressSnapshot(
        schemaVersion: 1, updatedAt: FixtureClock.epoch, level: 1,
        currentStreak: 0, longestStreak: 0, lastCompletedDate: nil, didCompleteOnboarding: false,
        practicedWordIds: [], masteredWordIds: [], bookmarkedWordIds: [],
        wordsWithTwoCorrectIds: [], wordsCreditedForLevelIds: [],
        selectedStacks: ["api-basic"], shuffleSeed: seed.uuidString, wordQueueCursor: 0,
        reviewStates: [], assessmentResults: [], practicedSentences: [], bookProgress: [])

    /// Mid-game: populated sets, sub-records, non-nil dates — exercises every key.
    static let rich = ProgressSnapshot(
        schemaVersion: 1, updatedAt: FixtureClock.plusDays(30), level: 8,
        currentStreak: 5, longestStreak: 12,
        lastCompletedDate: FixtureClock.plusDays(29), didCompleteOnboarding: true,
        practicedWordIds: [uid("api-bas-0001-cache"), uid("gcp-bas-0010-vpc")].sorted(),
        masteredWordIds: [uid("api-bas-0001-cache")].sorted(),
        bookmarkedWordIds: [uid("gcp-bas-0010-vpc")].sorted(),
        wordsWithTwoCorrectIds: [uid("api-bas-0001-cache")].sorted(),
        wordsCreditedForLevelIds: [uid("api-bas-0001-cache"), uid("gcp-bas-0010-vpc")].sorted(),
        selectedStacks: ["api-basic", "gcp-basic"], shuffleSeed: seed.uuidString, wordQueueCursor: 17,
        reviewStates: [
            Review(wordId: uid("api-bas-0001-cache"), easinessFactor: 2.6, interval: 6,
                   repetitions: 2, dueDate: FixtureClock.plusDays(36), lastReviewedAt: FixtureClock.plusDays(29)),
            Review(wordId: uid("gcp-bas-0010-vpc"), easinessFactor: 2.5, interval: 1,
                   repetitions: 1, dueDate: FixtureClock.plusDays(31), lastReviewedAt: FixtureClock.plusDays(30)),
        ],
        assessmentResults: [
            Assessment(id: uid("assess-1"), wordId: uid("api-bas-0001-cache"), attemptedAt: FixtureClock.plusDays(28),
                       isCorrect: true, selectedAnswer: "a stored copy", correctAnswer: "a stored copy"),
        ],
        practicedSentences: [
            Sentence(wordId: uid("api-bas-0001-cache"), sentence: "We cache responses at the edge.",
                     createdAt: FixtureClock.plusDays(28), inputMethod: "text"),
        ],
        bookProgress: [
            Book(bookId: "designing-apis", lastOpenedAt: FixtureClock.plusDays(27),
                 currentChapterId: "api-ch03", currentCardId: "api-ch03-c002",
                 completedCardIds: ["api-ch03-c001", "api-ch03-c002"].sorted(),
                 lastReadingDayString: "2026-01-28", currentStreakDays: 3, longestStreakDays: 7),
        ])

    /// Stress the nil-omission contract: nil dates and nil book position keys
    /// must be *absent* from the JSON, not `null`.
    static let nilOptionals = ProgressSnapshot(
        schemaVersion: 1, updatedAt: FixtureClock.plusDays(2), level: 2,
        currentStreak: 1, longestStreak: 1, lastCompletedDate: nil, didCompleteOnboarding: true,
        practicedWordIds: [uid("gcp-bas-0010-vpc")], masteredWordIds: [], bookmarkedWordIds: [],
        wordsWithTwoCorrectIds: [], wordsCreditedForLevelIds: [],
        selectedStacks: ["gcp-basic"], shuffleSeed: seed.uuidString, wordQueueCursor: 1,
        reviewStates: [
            Review(wordId: uid("gcp-bas-0010-vpc"), easinessFactor: 2.5, interval: 1,
                   repetitions: 0, dueDate: FixtureClock.plusDays(3), lastReviewedAt: nil),
        ],
        assessmentResults: [], practicedSentences: [],
        bookProgress: [
            Book(bookId: "designing-apis", lastOpenedAt: FixtureClock.plusDays(1),
                 currentChapterId: nil, currentCardId: nil, completedCardIds: [],
                 lastReadingDayString: "2026-01-02", currentStreakDays: 1, longestStreakDays: 1),
        ])

    // MARK: - Merge cases (local, remote) → generator computes `expected`

    struct RawMergeCase { let name: String; let local: ProgressSnapshot; let remote: ProgressSnapshot }

    static let mergeCases: [RawMergeCase] = [
        // Disjoint sets union; counters take the max; streak from later completion;
        // seed from later updatedAt.
        RawMergeCase(
            name: "disjoint-progress",
            local: ProgressSnapshot(
                schemaVersion: 1, updatedAt: FixtureClock.plusDays(10), level: 5,
                currentStreak: 3, longestStreak: 8, lastCompletedDate: FixtureClock.plusDays(9),
                didCompleteOnboarding: true,
                practicedWordIds: [uid("api-bas-0001-cache")], masteredWordIds: [],
                bookmarkedWordIds: [], wordsWithTwoCorrectIds: [], wordsCreditedForLevelIds: [uid("api-bas-0001-cache")],
                selectedStacks: ["api-basic"], shuffleSeed: uid("seed-local"), wordQueueCursor: 10,
                reviewStates: [], assessmentResults: [], practicedSentences: [], bookProgress: []),
            remote: ProgressSnapshot(
                schemaVersion: 1, updatedAt: FixtureClock.plusDays(12), level: 4,
                currentStreak: 1, longestStreak: 10, lastCompletedDate: FixtureClock.plusDays(7),
                didCompleteOnboarding: false,
                practicedWordIds: [uid("gcp-bas-0010-vpc")], masteredWordIds: [uid("gcp-bas-0010-vpc")],
                bookmarkedWordIds: [], wordsWithTwoCorrectIds: [], wordsCreditedForLevelIds: [uid("gcp-bas-0010-vpc")],
                selectedStacks: ["gcp-basic"], shuffleSeed: uid("seed-remote"), wordQueueCursor: 20,
                reviewStates: [], assessmentResults: [], practicedSentences: [], bookProgress: [])),

        // Same word reviewed on both sides → keep the later lastReviewedAt.
        RawMergeCase(
            name: "overlapping-review-states",
            local: ProgressSnapshot(
                schemaVersion: 1, updatedAt: FixtureClock.plusDays(5), level: 3,
                currentStreak: 2, longestStreak: 2, lastCompletedDate: FixtureClock.plusDays(5),
                didCompleteOnboarding: true,
                practicedWordIds: [uid("api-bas-0001-cache")], masteredWordIds: [], bookmarkedWordIds: [],
                wordsWithTwoCorrectIds: [], wordsCreditedForLevelIds: [],
                selectedStacks: ["api-basic"], shuffleSeed: seed.uuidString, wordQueueCursor: 5,
                reviewStates: [
                    Review(wordId: uid("api-bas-0001-cache"), easinessFactor: 2.5, interval: 1,
                           repetitions: 1, dueDate: FixtureClock.plusDays(6), lastReviewedAt: FixtureClock.plusDays(5)),
                ],
                assessmentResults: [], practicedSentences: [], bookProgress: []),
            remote: ProgressSnapshot(
                schemaVersion: 1, updatedAt: FixtureClock.plusDays(8), level: 3,
                currentStreak: 4, longestStreak: 4, lastCompletedDate: FixtureClock.plusDays(8),
                didCompleteOnboarding: true,
                practicedWordIds: [uid("api-bas-0001-cache")], masteredWordIds: [], bookmarkedWordIds: [],
                wordsWithTwoCorrectIds: [], wordsCreditedForLevelIds: [],
                selectedStacks: ["api-basic"], shuffleSeed: seed.uuidString, wordQueueCursor: 8,
                reviewStates: [
                    Review(wordId: uid("api-bas-0001-cache"), easinessFactor: 2.6, interval: 6,
                           repetitions: 2, dueDate: FixtureClock.plusDays(14), lastReviewedAt: FixtureClock.plusDays(8)),
                ],
                assessmentResults: [], practicedSentences: [], bookProgress: [])),
    ]
}
