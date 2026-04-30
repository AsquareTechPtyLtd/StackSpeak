import Foundation
import SwiftData

/// View state for a single book — header info, the chapter list with `X / N`
/// completion indicators, and the per-book streak toast that fires when the
/// user opens a book they've kept a multi-day streak in.
@MainActor
@Observable
final class BookDetailViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    var loadState: LoadState = .idle
    private(set) var manifest: BookManifest?
    private(set) var bookProgress: BookProgress?

    /// True for one render after `open(...)` if the streak meets the toast threshold.
    /// View consumes this via `consumeStreakToast()` so the toast fires once per session.
    private(set) var pendingStreakToastDays: Int?

    /// Latches once the toast has emitted in this VM lifetime. Prevents the
    /// toast from re-firing if the view re-opens the book while the VM is alive.
    private var hasEmittedStreakToast: Bool = false

    /// Returns chapters in `order` ascending — defensive against a manifest that
    /// happens to be authored out of order.
    var orderedChapters: [ChapterSummary] {
        manifest?.chapters.sorted { $0.order < $1.order } ?? []
    }

    /// Per-chapter completion ratio, computed as the intersection of
    /// `BookProgress.completedCardIds` ∩ `chapter.cardIds`. Returns 0 when no
    /// cards completed; up to 1.0 when chapter is fully done.
    func completionRatio(for chapter: ChapterSummary) -> Double {
        guard let bookProgress, !chapter.cardIds.isEmpty else { return 0 }
        let completed = bookProgress.completedCardIds
        let intersect = chapter.cardIds.filter { completed.contains($0) }.count
        return Double(intersect) / Double(chapter.cardIds.count)
    }

    func completedCount(for chapter: ChapterSummary) -> Int {
        guard let bookProgress else { return 0 }
        let completed = bookProgress.completedCardIds
        return chapter.cardIds.filter { completed.contains($0) }.count
    }

    /// Loads the manifest + progress and schedules a streak toast if the
    /// per-book streak is ≥ 2. Idempotent for the same `bookId` — calling this
    /// twice will not re-emit the toast within the same ViewModel instance.
    func open(
        bookId: String,
        catalogService: BookCatalogService,
        contentSource: any BookContentSource,
        modelContext: ModelContext,
        now: Date = Date()
    ) async {
        loadState = .loading
        do {
            let manifest = try await contentSource.loadManifest(bookId: bookId)
            self.manifest = manifest
        } catch {
            loadState = .failed(error.localizedDescription)
            return
        }

        // Fetch or create per-book progress.
        let progress = fetchOrCreateProgress(bookId: bookId, modelContext: modelContext)
        progress.lastOpenedAt = now
        bookProgress = progress

        // Streak toast: emit only when current streak is ≥ 2 AND hasn't fired
        // already in this VM's lifetime (suppresses re-emission on re-open).
        if progress.currentStreakDays >= 2 && !hasEmittedStreakToast {
            pendingStreakToastDays = progress.currentStreakDays
            hasEmittedStreakToast = true
        }

        try? modelContext.save()
        loadState = .loaded
    }

    /// Consumes (and clears) the pending streak toast value. Caller animates and
    /// dismisses; ViewModel does not re-emit until `open` is called fresh.
    func consumeStreakToast() -> Int? {
        let value = pendingStreakToastDays
        pendingStreakToastDays = nil
        return value
    }

    /// Refreshes `bookProgress` after a card flow session ends so the chapter
    /// rows re-render with new completion ratios.
    func refreshProgress(modelContext: ModelContext) {
        guard let manifest else { return }
        bookProgress = fetchOrCreateProgress(bookId: manifest.id, modelContext: modelContext)
    }

    private func fetchOrCreateProgress(bookId: String, modelContext: ModelContext) -> BookProgress {
        let descriptor = FetchDescriptor<BookProgress>(
            predicate: #Predicate { $0.bookId == bookId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let new = BookProgress(bookId: bookId)
        modelContext.insert(new)
        return new
    }
}
