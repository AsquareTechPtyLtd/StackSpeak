import Foundation
import SwiftData

// Pro entitlement + daily counters for UserProgress — split out per the
// <TypeName>+<Concern>.swift convention to keep the primary file under the
// size limit.
extension UserProgress {
    /// Single source of truth for Pro entitlement. True when the user holds the
    /// one-time lifetime purchase, or an active subscription with a future expiry.
    var isProActive: Bool {
        if isLifetimePro { return true }
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
