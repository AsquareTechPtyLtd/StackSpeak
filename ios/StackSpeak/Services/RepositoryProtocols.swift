import Foundation
import SwiftData
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
}

/// Protocol for user progress data access
@MainActor
protocol ProgressRepository {
    func markWordPracticed(wordId: UUID, sentence: String, inputMethod: InputMethod, userProgress: UserProgress)
    func markWordMastered(_ wordId: UUID, userProgress: UserProgress)
    func unmarkWordMastered(_ wordId: UUID, userProgress: UserProgress)
    func toggleBookmark(_ wordId: UUID, userProgress: UserProgress)
    func completeDailySet(_ dailySet: DailySet, userProgress: UserProgress) throws
    func recordAssessmentResult(
        wordId: UUID,
        isCorrect: Bool,
        selectedAnswer: String,
        correctAnswer: String,
        userProgress: UserProgress
    ) -> Int?
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
