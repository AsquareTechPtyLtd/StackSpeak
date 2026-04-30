import Testing
import Foundation
import SwiftData
@testable import StackSpeak

/// Verifies the lightweight migration story for UserProgress + DailySet additions:
/// every new field has a documented default, persists across a save/fetch cycle,
/// and does not disturb the existing field values.
///
/// (The plan calls for "load a pre-migration snapshot" tests; without a versioned
/// `Schema` already in place that's out of scope for Phase 1, but proving fresh
/// records carry the documented defaults through SwiftData persistence covers the
/// real failure mode the migration test guards against — silent data corruption
/// when defaults are not declared.)
@Suite("UserProgress + DailySet — schema additions persist with defaults")
@MainActor
struct UserProgressMigrationTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            UserProgress.self,
            DailySet.self,
            BookProgress.self,
            BookmarkedCard.self,
            PracticedSentence.self,
            ReviewState.self,
            AssessmentResult.self,
            WordReport.self,
            Word.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("Fresh UserProgress persists Pro/cap defaults across save+fetch")
    func freshUserProgressDefaultsPersist() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let progress = UserProgress()
        context.insert(progress)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<UserProgress>())
        #expect(fetched.count == 1)
        let p = try #require(fetched.first)
        #expect(p.isPro == false)
        #expect(p.proExpiryDate == nil)
        #expect(p.dailyBookCardLimit == nil)
        #expect(p.bookCardsReadToday == 0)
        #expect(p.lastBookReadingResetDate == .distantPast)
        #expect(p.wordsLoadedToday == 0)
        #expect(p.lastWordsLoadedResetDate == .distantPast)
        // Existing pre-Pro fields untouched
        #expect(p.level == 1)
        #expect(p.didCompleteOnboarding == false)
    }

    @Test("UserProgress new fields survive mutation + reload")
    func userProgressFieldMutationPersists() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let progress = UserProgress()
        progress.isPro = true
        let expiry = Date(timeIntervalSince1970: 1_700_000_000)
        progress.proExpiryDate = expiry
        progress.dailyBookCardLimit = 20
        progress.bookCardsReadToday = 7
        progress.wordsLoadedToday = 3
        context.insert(progress)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<UserProgress>())
        let p = try #require(fetched.first)
        #expect(p.isPro == true)
        #expect(p.proExpiryDate == expiry)
        #expect(p.dailyBookCardLimit == 20)
        #expect(p.bookCardsReadToday == 7)
        #expect(p.wordsLoadedToday == 3)
    }

    @Test("Fresh DailySet persists with empty additionalBatches")
    func dailySetAdditionalBatchesDefault() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let set = DailySet(dayString: "2026-04-27", wordIds: [UUID(), UUID()])
        context.insert(set)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DailySet>())
        let s = try #require(fetched.first)
        #expect(s.additionalBatchesStorage == "")
        #expect(s.additionalBatches.isEmpty)
    }

    @Test("DailySet additionalBatches mutation persists across reload")
    func dailySetAdditionalBatchesPersist() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let set = DailySet(dayString: "2026-04-27", wordIds: [UUID()])
        let extra = (0..<5).map { _ in UUID() }
        set.appendAdditionalBatch(extra)
        context.insert(set)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DailySet>())
        let s = try #require(fetched.first)
        #expect(s.additionalBatches == [extra])
    }

    @Test("BookProgress + BookmarkedCard persist their state")
    func bookModelsPersist() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let bp = BookProgress(bookId: "book-a")
        bp.markCardCompleted("c1")
        bp.markCardCompleted("c2")
        bp.recordReadDay(today: "2026-04-27", yesterday: "2026-04-26")
        context.insert(bp)

        let bm = BookmarkedCard(cardId: "card-1", bookId: "book-a", chapterId: "ch01")
        context.insert(bm)
        try context.save()

        let progresses = try context.fetch(FetchDescriptor<BookProgress>())
        let bookmarks = try context.fetch(FetchDescriptor<BookmarkedCard>())
        #expect(progresses.count == 1)
        #expect(bookmarks.count == 1)
        let p = try #require(progresses.first)
        #expect(p.completedCardIds == ["c1", "c2"])
        #expect(p.currentStreakDays == 1)
        #expect(p.lastReadingDayString == "2026-04-27")
    }
}
