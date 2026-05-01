import Foundation

/// Lock state of a book in the Books tab — drives badge colour and tap behaviour.
enum BookLockState: String, Sendable, Equatable {
    /// `freeForAll` book — always usable by every user.
    case free
    /// Pro book, user has no active subscription. Tap opens paywall.
    case locked
    /// Pro book, user has an active subscription. Tap opens the book.
    case unlocked
}

/// Loads the books catalog from a content source and computes per-book lock state.
///
/// Catalog is small (one entry per book) so we cache the first load in-memory and
/// reuse for the session. Phase 7's `RemoteBookSource` will refresh-on-launch.
@MainActor
final class BookCatalogService {
    private let source: any BookContentSource
    private var cachedCatalog: BooksCatalog?

    init(source: any BookContentSource) {
        self.source = source
    }

    /// Returns the cached catalog or loads it from the source.
    func loadCatalog() async throws -> BooksCatalog {
        if let cached = cachedCatalog { return cached }
        let catalog = try await source.loadCatalog()
        cachedCatalog = catalog
        return catalog
    }

    /// Force a re-fetch from the source (e.g. catalog file replaced via remote refresh).
    func refresh() async throws -> BooksCatalog {
        cachedCatalog = nil
        return try await loadCatalog()
    }

    /// Single source of truth for "is this book unlocked for this user".
    /// `freeForAll` short-circuits the entitlement check so the free book is always usable.
    func lockState(for book: BookSummary, userProgress: UserProgress) -> BookLockState {
        if book.freeForAll { return .free }
        return userProgress.isProActive ? .unlocked : .locked
    }
}
