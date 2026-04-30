import Testing
import Foundation
import SwiftData
@testable import StackSpeak

@Suite("CardFlowViewModel — navigation + completion")
@MainActor
struct CardFlowViewModelNavigationTests {

    private func makeChapter(cardCount: Int = 3) -> ChapterSummary {
        let cardIds = (1...cardCount).map { "c\($0)" }
        return ChapterSummary(
            id: "ch1", order: 1, title: "Ch1", summary: "",
            icon: "book", cardCount: cardCount, cardIds: cardIds,
            shards: ["chapters/ch1.json"]
        )
    }

    private func makeMock(cardCount: Int = 3) -> MockBookContentSource {
        let mock = MockBookContentSource()
        let cards = (1...cardCount).map { i in
            BookCard(
                id: "c\(i)", order: i,
                title: "Card \(i)", teaser: "t\(i)",
                explanation: [.paragraph(runs: [InlineRun(text: "e\(i)")])],
                feynman: []
            )
        }
        mock.shards["book/ch1"] = cards
        return mock
    }

    private func loadVM(cardCount: Int = 3) async -> CardFlowViewModel {
        let mock = makeMock(cardCount: cardCount)
        let chapter = makeChapter(cardCount: cardCount)
        let vm = CardFlowViewModel()
        await vm.load(bookId: "book", chapter: chapter, contentSource: mock)
        return vm
    }

    @Test("next clamps at last card; previous clamps at 0")
    func clampingAtBoundaries() async {
        let vm = await loadVM(cardCount: 3)
        #expect(vm.currentIndex == 0)
        vm.previous()
        #expect(vm.currentIndex == 0)
        vm.next(); vm.next(); vm.next()
        #expect(vm.currentIndex == 2)  // clamped, not 3
    }

    @Test("resumeIfPossible jumps to a known cardId in the chapter")
    func resumeJumpsToCard() async {
        let vm = await loadVM(cardCount: 3)
        vm.resumeIfPossible(at: "c2")
        #expect(vm.currentIndex == 1)
    }

    @Test("resumeIfPossible is a no-op for unknown card id")
    func resumeIgnoresUnknown() async {
        let vm = await loadVM(cardCount: 3)
        vm.resumeIfPossible(at: "absent")
        #expect(vm.currentIndex == 0)
    }
}

@Suite("CardFlowViewModel — markComplete")
@MainActor
struct CardFlowViewModelMarkCompleteTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            BookProgress.self, BookmarkedCard.self,
            UserProgress.self, DailySet.self,
            Word.self, PracticedSentence.self,
            ReviewState.self, AssessmentResult.self, WordReport.self
        ])
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }

    private func loadVM(cardCount: Int = 3) async -> CardFlowViewModel {
        let mock = MockBookContentSource()
        let cards = (1...cardCount).map { i in
            BookCard(
                id: "c\(i)", order: i,
                title: "Card \(i)", teaser: "t\(i)",
                explanation: [.paragraph(runs: [InlineRun(text: "e\(i)")])],
                feynman: []
            )
        }
        mock.shards["book/ch1"] = cards
        let chapter = ChapterSummary(
            id: "ch1", order: 1, title: "Ch1", summary: "",
            icon: "book", cardCount: cardCount,
            cardIds: cards.map(\.id),
            shards: ["chapters/ch1.json"]
        )
        let vm = CardFlowViewModel()
        await vm.load(bookId: "book", chapter: chapter, contentSource: mock)
        return vm
    }

    @Test("Marks card complete and advances on non-last card")
    func advancesAfterMark() async {
        let vm = await loadVM(cardCount: 3)
        let bookProgress = BookProgress(bookId: "book")
        let userProgress = UserProgress()
        let result = vm.markComplete(bookProgress: bookProgress, userProgress: userProgress)
        guard case .advanced(let toIndex) = result else {
            Issue.record("Expected .advanced, got \(result)")
            return
        }
        #expect(toIndex == 1)
        #expect(bookProgress.completedCardIds == ["c1"])
    }

    @Test("Last card completion returns .chapterCompleted")
    func chapterCompleteOnLast() async {
        let vm = await loadVM(cardCount: 2)
        vm.next() // index = 1 (last)
        let bookProgress = BookProgress(bookId: "book")
        let userProgress = UserProgress()
        let result = vm.markComplete(bookProgress: bookProgress, userProgress: userProgress)
        #expect(result == .chapterCompleted)
        #expect(bookProgress.completedCardIds == ["c2"])
    }

    @Test("Re-marking the same card is idempotent (no double-counting)")
    func idempotentMark() async {
        let vm = await loadVM(cardCount: 3)
        let bookProgress = BookProgress(bookId: "book")
        let userProgress = UserProgress()
        _ = vm.markComplete(bookProgress: bookProgress, userProgress: userProgress)
        // Step back, mark same card again.
        vm.previous()
        _ = vm.markComplete(bookProgress: bookProgress, userProgress: userProgress)
        #expect(bookProgress.completedCardIds == ["c1"])
        // Cap counter only incremented once for that card.
        #expect(userProgress.bookCardsReadToday == 1)
    }

    @Test("First card of a new local day increments streak and cap counter")
    func firstCardIncrementsStreakAndCap() async {
        let vm = await loadVM(cardCount: 3)
        let bookProgress = BookProgress(bookId: "book")
        let userProgress = UserProgress()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let cal = Calendar(identifier: .gregorian)
        _ = vm.markComplete(
            bookProgress: bookProgress,
            userProgress: userProgress,
            now: day,
            calendar: cal
        )
        #expect(bookProgress.currentStreakDays == 1)
        #expect(userProgress.bookCardsReadToday == 1)
    }

    @Test("Cap-reached returns .capReached and does not mutate progress")
    func capBlocksWhenLimitReached() async {
        let vm = await loadVM(cardCount: 3)
        let bookProgress = BookProgress(bookId: "book")
        let userProgress = UserProgress()
        userProgress.dailyBookCardLimit = 1
        // Pre-load one read so we're already at the cap.
        userProgress.recordBookCardRead()

        let result = vm.markComplete(bookProgress: bookProgress, userProgress: userProgress)
        #expect(result == .capReached)
        #expect(bookProgress.completedCardIds.isEmpty)
        // Cap counter unchanged because the read was blocked.
        #expect(userProgress.bookCardsReadToday == 1)
    }

    @Test("Override punches through the cap and proceeds")
    func overrideBypassesCap() async {
        let vm = await loadVM(cardCount: 3)
        let bookProgress = BookProgress(bookId: "book")
        let userProgress = UserProgress()
        userProgress.dailyBookCardLimit = 1
        userProgress.recordBookCardRead()  // hit the cap

        let result = vm.markComplete(
            bookProgress: bookProgress,
            userProgress: userProgress,
            override: true
        )
        if case .advanced = result { } else {
            Issue.record("Expected .advanced, got \(result)")
        }
        #expect(bookProgress.completedCardIds == ["c1"])
        #expect(userProgress.bookCardsReadToday == 2) // override incremented past cap
    }

    @Test("BookProgress.currentCardId is updated for resume")
    func currentCardIdUpdated() async {
        let vm = await loadVM(cardCount: 3)
        let bookProgress = BookProgress(bookId: "book")
        let userProgress = UserProgress()
        _ = vm.markComplete(bookProgress: bookProgress, userProgress: userProgress)
        #expect(bookProgress.currentCardId == "c1")
        _ = vm.markComplete(bookProgress: bookProgress, userProgress: userProgress)
        #expect(bookProgress.currentCardId == "c2")
    }

    @Test("recordChapterEntry sets currentChapterId")
    func recordChapterEntrySets() async {
        let vm = await loadVM(cardCount: 1)
        let bookProgress = BookProgress(bookId: "book")
        vm.recordChapterEntry(bookProgress: bookProgress, chapterId: "ch1")
        #expect(bookProgress.currentChapterId == "ch1")
    }
}
