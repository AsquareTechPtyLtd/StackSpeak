import Foundation

extension BookProgress {
    /// Records that the user read at least one card today. Idempotent within a day.
    /// `today` and `yesterday` are passed in to keep the call deterministic across timezones / tests.
    func recordReadDay(today: String, yesterday: String) {
        if lastReadingDayString == today { return }
        if lastReadingDayString == yesterday {
            currentStreakDays += 1
        } else {
            currentStreakDays = 1
        }
        longestStreakDays = max(longestStreakDays, currentStreakDays)
        lastReadingDayString = today
    }

    /// Adds a card to the completed set. Idempotent.
    func markCardCompleted(_ cardId: String) {
        var ids = completedCardIds
        if ids.insert(cardId).inserted {
            completedCardIds = ids
        }
    }
}
