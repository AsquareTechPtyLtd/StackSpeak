import Foundation
import SwiftData

@Model
final class UserProgress {
    @Attribute(.unique) var userId: UUID
    var level: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletedDate: Date?
    var wordsPracticedIds: Set<UUID>
    var masteredWordIds: Set<UUID>
    var bookmarkedWordIds: Set<UUID>
    var installDate: Date
    var shuffleSeed: UUID
    /// Cursor position in the deterministic word queue. Advances after each daily set is generated.
    var wordQueueCursor: Int
    /// Denormalized cache of word IDs that have ≥2 correct assessment answers.
    /// Updated incrementally in ProgressService to avoid O(n) scans on every render.
    var wordsWithTwoCorrectIds: Set<UUID>
    /// Set when the user finishes onboarding (or skips it). Used to detect first-launch.
    var didCompleteOnboarding: Bool

    var notificationEnabled: Bool
    var notificationTime: Date?
    var secondReminderEnabled: Bool
    var secondReminderTime: Date?

    var themePreference: ThemePreference
    var densityPreference: DensityPreference

    var selectedStacks: Set<String>

    @Relationship(deleteRule: .cascade) var practicedSentences: [PracticedSentence]
    @Relationship(deleteRule: .cascade) var reviewStates: [ReviewState]
    @Relationship(deleteRule: .cascade) var assessmentResults: [AssessmentResult]

    var wordsPracticedCount: Int {
        wordsPracticedIds.count
    }

    var wordsAssessedCorrectlyTwice: Int {
        wordsWithTwoCorrectIds.count
    }

    /// Returns the streak to display, accounting for whether the streak is still active.
    /// A streak that hasn't been extended today or yesterday is shown as 0.
    var displayedCurrentStreak: Int {
        guard let lastCompleted = lastCompletedDate else { return 0 }
        let today = Calendar.current.startOfDay(for: Date())
        let last = Calendar.current.startOfDay(for: lastCompleted)
        let days = Calendar.current.dateComponents([.day], from: last, to: today).day ?? 0
        return days > 1 ? 0 : currentStreak
    }

    init() {
        self.userId = UUID()
        self.level = 1
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastCompletedDate = nil
        self.wordsPracticedIds = []
        self.masteredWordIds = []
        self.bookmarkedWordIds = []
        self.installDate = Date()
        self.shuffleSeed = UUID()
        self.wordQueueCursor = 0
        self.wordsWithTwoCorrectIds = []
        self.didCompleteOnboarding = false
        self.notificationEnabled = false
        self.notificationTime = nil
        self.secondReminderEnabled = false
        self.secondReminderTime = nil
        self.themePreference = .system
        self.densityPreference = .roomy
        self.selectedStacks = Set(WordStack.mandatoryStacks(for: 1).map { $0.rawValue })
        self.practicedSentences = []
        self.reviewStates = []
        self.assessmentResults = []
    }

    func addMandatoryStacks(for level: Int) {
        let newMandatory = WordStack.mandatoryStacks(for: level)
        var updated = selectedStacks
        updated.formUnion(newMandatory.map { $0.rawValue })
        selectedStacks = updated
    }
}

@Model
final class PracticedSentence {
    var wordId: UUID
    var sentence: String
    var createdAt: Date
    var inputMethod: InputMethod

    init(wordId: UUID, sentence: String, createdAt: Date, inputMethod: InputMethod) {
        self.wordId = wordId
        self.sentence = sentence
        self.createdAt = createdAt
        self.inputMethod = inputMethod
    }
}

@Model
final class ReviewState {
    var wordId: UUID
    var easinessFactor: Double
    var interval: Int
    var repetitions: Int
    var dueDate: Date
    var lastReviewedAt: Date?

    init(wordId: UUID) {
        self.wordId = wordId
        self.easinessFactor = 2.5
        self.interval = 1
        self.repetitions = 0
        self.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        self.lastReviewedAt = nil
    }

    func updateAfterReview(quality: Int) {
        lastReviewedAt = Date()

        if quality < 3 {
            repetitions = 0
            interval = 1
        } else {
            easinessFactor = max(1.3, easinessFactor + (0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02)))

            if repetitions == 0 {
                interval = 1
            } else if repetitions == 1 {
                interval = 6
            } else {
                interval = Int(Double(interval) * easinessFactor)
            }

            repetitions += 1
        }

        dueDate = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
    }
}

@Model
final class AssessmentResult {
    var id: UUID
    var wordId: UUID
    var attemptedAt: Date
    var isCorrect: Bool
    var selectedAnswer: String
    var correctAnswer: String

    init(wordId: UUID, attemptedAt: Date, isCorrect: Bool, selectedAnswer: String, correctAnswer: String) {
        self.id = UUID()
        self.wordId = wordId
        self.attemptedAt = attemptedAt
        self.isCorrect = isCorrect
        self.selectedAnswer = selectedAnswer
        self.correctAnswer = correctAnswer
    }
}

extension UserProgress {
    func correctAssessmentCount(for wordId: UUID) -> Int {
        assessmentResults.filter { $0.wordId == wordId && $0.isCorrect }.count
    }

    func canAttemptAssessment(for wordId: UUID) -> Bool {
        let lastAttempt = assessmentResults
            .filter({ $0.wordId == wordId })
            .max(by: { $0.attemptedAt < $1.attemptedAt })

        guard let lastAttempt else { return true }

        // One attempt per word per calendar day — correct or not.
        // The second (and final) correct attempt must happen on a different day.
        let cal = Calendar.current
        return !cal.isDateInToday(lastAttempt.attemptedAt)
    }

    /// Rebuilds `wordsWithTwoCorrectIds` from raw results. Used for migration / testing only.
    /// Normal updates happen incrementally in ProgressService.recordAssessmentResult.
    func rebuildTwoCorrectCache() {
        let wordCorrectCounts = Dictionary(grouping: assessmentResults.filter { $0.isCorrect }) { $0.wordId }
            .mapValues { $0.count }
        wordsWithTwoCorrectIds = Set(wordCorrectCounts.filter { $0.value >= 2 }.keys)
    }

    func wordsEligibleForAssessment() -> Set<UUID> {
        wordsPracticedIds.subtracting(wordsWithTwoCorrectIds)
    }
}

enum InputMethod: String, Codable {
    case typed
    case voice
}

enum ThemePreference: String, Codable {
    case system
    case light
    case dark
}

enum DensityPreference: String, Codable {
    case compact
    case roomy
}
