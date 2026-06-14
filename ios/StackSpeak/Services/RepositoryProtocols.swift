import Foundation
import SwiftData
import StoreKit
import UserNotifications
import Speech

// MARK: - Repository Protocols

/// Protocol for word data access - decouples views from SwiftData implementation
@MainActor
protocol WordRepository {
    func loadWordsFromBundle() async throws
    func fetchWord(byId id: UUID) throws -> Word?
    func fetchWords(matching query: String, filters: WordFilters) throws -> [Word]
    func generateDailySet(for date: Date, userProgress: UserProgress) throws -> DailySet
    @discardableResult
    func setDailyWordGoal(_ goal: Int, userProgress: UserProgress) throws -> DailySet
}

/// Protocol for user progress data access
@MainActor
protocol ProgressRepository {
    func markWordPracticed(wordId: UUID, sentence: String, inputMethod: InputMethod, markAsMastered: Bool, userProgress: UserProgress) throws
    @discardableResult
    func recordWordCompletion(wordId: UUID, sentence: String, inputMethod: InputMethod, markAsMastered: Bool, dailySet: DailySet, userProgress: UserProgress) throws -> Bool
    func markWordMastered(_ wordId: UUID, userProgress: UserProgress) throws
    func unmarkWordMastered(_ wordId: UUID, userProgress: UserProgress) throws
    func toggleBookmark(_ wordId: UUID, userProgress: UserProgress) throws
    func completeDailySet(_ dailySet: DailySet, userProgress: UserProgress) throws
    func addOptionalStacks(_ rawValues: [String], to userProgress: UserProgress) throws
    func recordAssessmentResult(
        wordId: UUID,
        isCorrect: Bool,
        selectedAnswer: String,
        correctAnswer: String,
        userProgress: UserProgress
    ) throws -> Int?
    func getNewStacksForLevel(_ level: Int) -> (mandatory: Set<WordStack>, optional: Set<WordStack>)
}

/// Protocol for review/SRS data access
@MainActor
protocol ReviewRepository {
    func recordReview(reviewState: ReviewState, quality: ReviewQuality) throws
}

/// Protocol for notification management
@MainActor
protocol NotificationRepository {
    func requestAuthorization() async throws -> Bool
    func checkAuthorizationStatus() async -> UNAuthorizationStatus
    func scheduleDailyNotifications(at time: Date, isPrimary: Bool, count: Int) async throws
    func rescheduleNotifications(primary: Date?, secondary: Date?) async throws
    func cancelNotification(identifier: String)
    func cancelAllNotifications()
    func getPendingNotificationCount() async -> Int
    func resetBadge()
}

/// Protocol for the Pro subscription purchase flow (StoreKit 2)
@MainActor
protocol PurchaseRepository {
    /// Pro subscription products, sorted cheapest first. Empty until `loadProducts()` succeeds.
    var proProducts: [Product] { get }
    var isLoadingProducts: Bool { get }

    func startTransactionListener()
    func loadProducts() async
    /// Returns true when the purchase completed and Pro is now active.
    func purchase(_ product: Product) async throws -> Bool
    /// Returns true when Pro is active after replaying past transactions.
    func restorePurchases() async throws -> Bool
    func refreshEntitlement() async
}

/// Protocol for speech recognition
@MainActor
protocol SpeechRepository {
    var isRecording: Bool { get }
    var transcript: String { get }
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus { get }

    func requestAuthorization() async -> Bool
    func startRecording() throws
    func stopRecording()
    func reset()
}
