import Testing
import Foundation
@testable import StackSpeak

@Suite("UserProgress — Pro entitlement")
struct UserProgressProEntitlementTests {

    @Test("Default UserProgress has all Pro/cap fields at documented defaults")
    func defaultsAreSensible() {
        let p = UserProgress()
        #expect(p.isPro == false)
        #expect(p.proExpiryDate == nil)
        #expect(p.dailyBookCardLimit == nil)
        #expect(p.bookCardsReadToday == 0)
        #expect(p.lastBookReadingResetDate == .distantPast)
        #expect(p.wordsLoadedToday == 0)
        #expect(p.lastWordsLoadedResetDate == .distantPast)
        #expect(p.isProActive == false)
    }

    @Test("isProActive is true only when isPro=true and expiry is in the future")
    func isProActiveLogic() {
        let p = UserProgress()
        p.isPro = true
        p.proExpiryDate = Date().addingTimeInterval(60 * 60 * 24)
        #expect(p.isProActive == true)
    }

    @Test("isProActive is false when expiry is in the past")
    func isProActiveExpired() {
        let p = UserProgress()
        p.isPro = true
        p.proExpiryDate = Date().addingTimeInterval(-60)
        #expect(p.isProActive == false)
    }

    @Test("isProActive is false when isPro=false even with future expiry")
    func isProActiveFlagOff() {
        let p = UserProgress()
        p.isPro = false
        p.proExpiryDate = Date().addingTimeInterval(60 * 60 * 24)
        #expect(p.isProActive == false)
    }

    @Test("isProActive is false when proExpiryDate is nil")
    func isProActiveNilExpiry() {
        let p = UserProgress()
        p.isPro = true
        p.proExpiryDate = nil
        #expect(p.isProActive == false)
    }
}

@Suite("UserProgress — book reading cap counter")
struct UserProgressBookCapTests {

    @Test("Default nil limit never caps")
    func nilLimitNeverCaps() {
        let p = UserProgress()
        for _ in 0..<100 { p.recordBookCardRead() }
        #expect(p.bookCapReached == false)
    }

    @Test("Counter increments same day, resets on local midnight rollover")
    func resetAtLocalMidnight() {
        let cal = Calendar(identifier: .gregorian)
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = Date(timeIntervalSince1970: 1_700_000_000 + 60 * 60 * 24 * 2)
        let p = UserProgress()
        p.recordBookCardRead(now: day1, calendar: cal)
        p.recordBookCardRead(now: day1, calendar: cal)
        #expect(p.bookCardsReadToday == 2)

        p.recordBookCardRead(now: day2, calendar: cal)
        #expect(p.bookCardsReadToday == 1)
    }

    @Test("With limit set, cap reached at exactly the limit")
    func capAtLimit() {
        let p = UserProgress()
        p.dailyBookCardLimit = 3
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        p.recordBookCardRead(now: now, calendar: cal)
        p.recordBookCardRead(now: now, calendar: cal)
        #expect(p.bookCapReached == false)
        p.recordBookCardRead(now: now, calendar: cal)
        #expect(p.bookCapReached == true)
    }

    @Test("Cap survives further reads (counter keeps incrementing past cap)")
    func capPersistsPastLimit() {
        let p = UserProgress()
        p.dailyBookCardLimit = 2
        for _ in 0..<5 { p.recordBookCardRead() }
        #expect(p.bookCardsReadToday == 5)
        #expect(p.bookCapReached == true)
    }
}

@Suite("UserProgress — vocab load-more counter")
struct UserProgressVocabLoadMoreTests {

    @Test("Counter increments and resets at local midnight")
    func incrementAndReset() {
        let cal = Calendar(identifier: .gregorian)
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = Date(timeIntervalSince1970: 1_700_000_000 + 60 * 60 * 24 * 2)
        let p = UserProgress()
        for _ in 0..<5 { p.recordWordsLoadedToday(now: day1, calendar: cal) }
        #expect(p.wordsLoadedToday == 5)
        p.recordWordsLoadedToday(now: day2, calendar: cal)
        #expect(p.wordsLoadedToday == 1)
    }

    @Test("refreshWordsLoadedTodayIfNeeded resets without incrementing")
    func refreshDoesNotIncrement() {
        let cal = Calendar(identifier: .gregorian)
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = Date(timeIntervalSince1970: 1_700_000_000 + 60 * 60 * 24 * 2)
        let p = UserProgress()
        p.recordWordsLoadedToday(now: day1, calendar: cal)
        p.recordWordsLoadedToday(now: day1, calendar: cal)
        #expect(p.wordsLoadedToday == 2)
        p.refreshWordsLoadedTodayIfNeeded(now: day2, calendar: cal)
        #expect(p.wordsLoadedToday == 0)
        #expect(p.lastWordsLoadedResetDate == cal.startOfDay(for: day2))
    }
}
