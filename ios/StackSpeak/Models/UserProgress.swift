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
        wordsWithTwoCorrectAssessments().count
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
        selectedStacks.formUnion(newMandatory.map { $0.rawValue })
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
    @Attribute(.unique) var wordId: UUID
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
        guard let lastAttempt = assessmentResults
            .filter({ $0.wordId == wordId })
            .sorted(by: { $0.attemptedAt > $1.attemptedAt })
            .first else {
            return true
        }

        if lastAttempt.isCorrect {
            return true
        }

        let hoursSinceAttempt = Calendar.current.dateComponents([.hour], from: lastAttempt.attemptedAt, to: Date()).hour ?? 0
        return hoursSinceAttempt >= 24
    }

    func wordsWithTwoCorrectAssessments() -> Set<UUID> {
        let wordCorrectCounts = Dictionary(grouping: assessmentResults.filter { $0.isCorrect }) { $0.wordId }
            .mapValues { $0.count }

        return Set(wordCorrectCounts.filter { $0.value >= 2 }.keys)
    }

    func wordsEligibleForAssessment() -> Set<UUID> {
        wordsPracticedIds.subtracting(wordsWithTwoCorrectAssessments())
    }
}

@Model
final class AssessmentAttempt {
    @Attribute(.unique) var wordId: UUID
    var lastAttemptDate: Date?
    var correctCount: Int

    init(wordId: UUID) {
        self.wordId = wordId
        self.lastAttemptDate = nil
        self.correctCount = 0
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
