import Accessibility

/// Single wrapper around the imperative VoiceOver announcement API so the
/// three announcement sites (assessment auto-advance, Feynman stage change,
/// flashcard reset) stay on one code path if the API or policy changes.
enum VoiceOverAnnouncer {
    static func post(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}
