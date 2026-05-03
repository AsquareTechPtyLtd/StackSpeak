import Foundation
import SwiftData

@Model
final class UserProgress {
    @Attribute(.unique) var userId: UUID
    var level: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletedDate: Date?
    var wordsPracticedIdsStorage: String
    var masteredWordIdsStorage: String
    var bookmarkedWordIdsStorage: String
    var installDate: Date
    var shuffleSeed: UUID
    var wordQueueCursor: Int
    var wordsWithTwoCorrectIdsStorage: String
    var didCompleteOnboarding: Bool

    var notificationEnabled: Bool
    var notificationTime: Date?
    var secondReminderEnabled: Bool
    var secondReminderTime: Date?

    var themePreference: ThemePreference

    var selectedStacksStorage: String

    // MARK: - Pro subscription

    var isPro: Bool = false
    var proExpiryDate: Date? = nil

    // MARK: - Daily-5 vocab load-more (Pro feature)
    // Hard cap at 25 cards/day. Reset at local midnight.

    var wordsLoadedToday: Int = 0
    var lastWordsLoadedResetDate: Date = Date.distantPast

    // MARK: - Book reading preferences

    /// `nil` means unlimited (the default). A value sets a global daily cap across all books.
    /// Default value when first opting in: 20.
    var dailyBookCardLimit: Int? = nil
    var bookCardsReadToday: Int = 0
    var lastBookReadingResetDate: Date = Date.distantPast

    var wordsPracticedIds: Set<UUID> {
        get { Self.uuidsFromCSV(wordsPracticedIdsStorage) }
        set { wordsPracticedIdsStorage = Self.csvFromUUIDs(newValue) }
    }

    var masteredWordIds: Set<UUID> {
        get { Self.uuidsFromCSV(masteredWordIdsStorage) }
        set { masteredWordIdsStorage = Self.csvFromUUIDs(newValue) }
    }

    var bookmarkedWordIds: Set<UUID> {
        get { Self.uuidsFromCSV(bookmarkedWordIdsStorage) }
        set { bookmarkedWordIdsStorage = Self.csvFromUUIDs(newValue) }
    }

    var wordsWithTwoCorrectIds: Set<UUID> {
        get { Self.uuidsFromCSV(wordsWithTwoCorrectIdsStorage) }
        set { wordsWithTwoCorrectIdsStorage = Self.csvFromUUIDs(newValue) }
    }

    var selectedStacks: Set<String> {
        get { selectedStacksStorage.isEmpty ? [] : Set(selectedStacksStorage.components(separatedBy: ",")) }
        set { selectedStacksStorage = newValue.sorted().joined(separator: ",") }
    }

    private static func uuidsFromCSV(_ csv: String) -> Set<UUID> {
        guard !csv.isEmpty else { return [] }
        return Set(csv.components(separatedBy: ",").compactMap { UUID(uuidString: $0) })
    }

    private static func csvFromUUIDs(_ uuids: Set<UUID>) -> String {
        uuids.map(\.uuidString).joined(separator: ",")
    }

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
        self.wordsPracticedIdsStorage = ""
        self.masteredWordIdsStorage = ""
        self.bookmarkedWordIdsStorage = ""
        self.installDate = Date()
        self.shuffleSeed = UUID()
        self.wordQueueCursor = 0
        self.wordsWithTwoCorrectIdsStorage = ""
        self.didCompleteOnboarding = false
        self.notificationEnabled = false
        self.notificationTime = nil
        self.secondReminderEnabled = false
        self.secondReminderTime = nil
        self.themePreference = .system
        self.selectedStacksStorage = WordStack.mandatoryStacks(for: 1).map(\.rawValue).joined(separator: ",")
        self.isPro = false
        self.proExpiryDate = nil
        self.wordsLoadedToday = 0
        self.lastWordsLoadedResetDate = .distantPast
        self.dailyBookCardLimit = nil
        self.bookCardsReadToday = 0
        self.lastBookReadingResetDate = .distantPast
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
    /// SM-2 spaced-repetition algorithm tuning constants.
    private enum SM2 {
        static let initialEasiness = 2.5
        static let minEasiness = 1.3
        static let easinessIncrement = 0.1
        static let easinessQualityCoeff = 0.08
        static let easinessQualitySquaredCoeff = 0.02
        static let qualityFailThreshold = 3
        static let firstInterval = 1
        static let secondInterval = 6
    }

    var wordId: UUID
    var easinessFactor: Double
    var interval: Int
    var repetitions: Int
    var dueDate: Date
    var lastReviewedAt: Date?

    init(wordId: UUID) {
        self.wordId = wordId
        self.easinessFactor = SM2.initialEasiness
        self.interval = SM2.firstInterval
        self.repetitions = 0
        self.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        self.lastReviewedAt = nil
    }

    func updateAfterReview(quality: Int) {
        lastReviewedAt = Date()

        if quality < SM2.qualityFailThreshold {
            repetitions = 0
            interval = SM2.firstInterval
        } else {
            let qDelta = Double(5 - quality)
            let efAdjustment = SM2.easinessIncrement - qDelta * (SM2.easinessQualityCoeff + qDelta * SM2.easinessQualitySquaredCoeff)
            easinessFactor = max(SM2.minEasiness, easinessFactor + efAdjustment)

            switch repetitions {
            case 0: interval = SM2.firstInterval
            case 1: interval = SM2.secondInterval
            default: interval = Int(Double(interval) * easinessFactor)
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

    var wordsEligibleForAssessment: Set<UUID> {
        wordsPracticedIds.subtracting(wordsWithTwoCorrectIds)
    }
}

extension UserProgress {
    /// Single source of truth for Pro entitlement.
    /// True only when the user has an active subscription with a future expiry.
    var isProActive: Bool {
        guard isPro else { return false }
        guard let expiry = proExpiryDate else { return false }
        return expiry > Date()
    }

    /// Resets `counter` to 0 if `resetDate` is in a previous local day, then advances `resetDate`.
    private func resetDailyCounterIfNewDay(
        counter: ReferenceWritableKeyPath<UserProgress, Int>,
        resetDate: ReferenceWritableKeyPath<UserProgress, Date>,
        now: Date,
        calendar: Calendar
    ) {
        let today = calendar.startOfDay(for: now)
        if today > self[keyPath: resetDate] {
            self[keyPath: counter] = 0
            self[keyPath: resetDate] = today
        }
    }

    /// Records that one more vocab load-more card was served today.
    func recordWordsLoadedToday(now: Date = Date(), calendar: Calendar = .current) {
        resetDailyCounterIfNewDay(counter: \.wordsLoadedToday, resetDate: \.lastWordsLoadedResetDate, now: now, calendar: calendar)
        wordsLoadedToday += 1
    }

    /// Resets the daily vocab load-more counter if a new local day has begun.
    /// Use before reading `wordsLoadedToday` for cap checks.
    func refreshWordsLoadedTodayIfNeeded(now: Date = Date(), calendar: Calendar = .current) {
        resetDailyCounterIfNewDay(counter: \.wordsLoadedToday, resetDate: \.lastWordsLoadedResetDate, now: now, calendar: calendar)
    }

    /// Records that one more book card was read today.
    func recordBookCardRead(now: Date = Date(), calendar: Calendar = .current) {
        resetDailyCounterIfNewDay(counter: \.bookCardsReadToday, resetDate: \.lastBookReadingResetDate, now: now, calendar: calendar)
        bookCardsReadToday += 1
    }

    /// Resets the book reading counter if a new local day has begun. Idempotent.
    func refreshBookCardsReadIfNeeded(now: Date = Date(), calendar: Calendar = .current) {
        resetDailyCounterIfNewDay(counter: \.bookCardsReadToday, resetDate: \.lastBookReadingResetDate, now: now, calendar: calendar)
    }

    /// True when the user has opted into a daily book-reading cap and hit it today.
    /// `nil` limit (the default) never caps.
    var bookCapReached: Bool {
        guard let limit = dailyBookCardLimit else { return false }
        return bookCardsReadToday >= limit
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
