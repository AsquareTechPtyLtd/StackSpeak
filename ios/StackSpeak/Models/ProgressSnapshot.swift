import Foundation

/// The platform-neutral record that syncs across devices and platforms.
///
/// This is the **cross-platform contract**: iOS and (later) Android must
/// serialize the *identical* JSON shape so a user's progress is portable
/// between an iPhone, an iPad, and an Android device. It is stored as one
/// compact JSONB blob per user (see `supabase/migrations`).
///
/// Deliberately excluded: entitlement (`isPro`/`proExpiryDate`/`isLifetimePro`
/// — each device derives Pro from its own store), transient daily counters,
/// and device-local preferences (notifications, theme). Only learning progress
/// travels.
///
/// `schemaVersion` lets future shape changes migrate safely; `updatedAt` drives
/// last-write/merge decisions during sync.
struct ProgressSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var updatedAt: Date

    // Core progression
    var level: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletedDate: Date?
    var didCompleteOnboarding: Bool

    // Word-id sets (stable mnemonic-derived UUIDs, safe across platforms)
    var practicedWordIds: [String]
    var masteredWordIds: [String]
    var bookmarkedWordIds: [String]
    var wordsWithTwoCorrectIds: [String]
    var wordsCreditedForLevelIds: [String]

    // Rotation state — kept so the daily queue stays consistent across devices
    var selectedStacks: [String]
    var shuffleSeed: String
    var wordQueueCursor: Int

    // Sub-records
    var reviewStates: [ReviewStateDTO]
    var assessmentResults: [AssessmentResultDTO]
    var practicedSentences: [PracticedSentenceDTO]
    var bookProgress: [BookProgressDTO]

    struct ReviewStateDTO: Codable, Equatable {
        var wordId: String
        var easinessFactor: Double
        var interval: Int
        var repetitions: Int
        var dueDate: Date
        var lastReviewedAt: Date?
    }

    struct AssessmentResultDTO: Codable, Equatable {
        var id: String
        var wordId: String
        var attemptedAt: Date
        var isCorrect: Bool
        var selectedAnswer: String
        var correctAnswer: String
    }

    struct PracticedSentenceDTO: Codable, Equatable {
        var wordId: String
        var sentence: String
        var createdAt: Date
        var inputMethod: String
    }

    struct BookProgressDTO: Codable, Equatable {
        var bookId: String
        var lastOpenedAt: Date
        var currentChapterId: String?
        var currentCardId: String?
        var completedCardIds: [String]
        var lastReadingDayString: String
        var currentStreakDays: Int
        var longestStreakDays: Int
    }
}
