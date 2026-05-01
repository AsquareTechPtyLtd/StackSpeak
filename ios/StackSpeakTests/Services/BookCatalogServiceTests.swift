import Testing
import Foundation
@testable import StackSpeak

/// Test double for `BookContentSource` — never touches disk. Used by ViewModel and
/// service tests so they can run hermetically and seed any catalog/manifest shape.
@MainActor
final class MockBookContentSource: BookContentSource, @unchecked Sendable {
    var catalog: BooksCatalog
    var manifests: [String: BookManifest] = [:]
    var shards: [String: [BookCard]] = [:] // key = "\(bookId)/\(chapterId)"
    var loadCatalogCalls = 0

    init(catalog: BooksCatalog = BooksCatalog(version: 1, updatedAt: Date(), books: [])) {
        self.catalog = catalog
    }

    func loadCatalog() async throws -> BooksCatalog {
        loadCatalogCalls += 1
        return catalog
    }

    func loadManifest(bookId: String) async throws -> BookManifest {
        guard let manifest = manifests[bookId] else {
            throw BookContentError.manifestNotFound(bookId: bookId)
        }
        return manifest
    }

    func loadChapter(bookId: String, chapterId: String, shards: [String]) async throws -> [BookCard] {
        self.shards["\(bookId)/\(chapterId)"] ?? []
    }
}

@Suite("BookCatalogService — lock state computation")
@MainActor
struct BookCatalogServiceLockStateTests {

    private func makeBook(id: String, freeForAll: Bool) -> BookSummary {
        BookSummary(
            id: id, title: id, author: nil, summary: "s", coverIcon: "book",
            accentHex: nil, tags: [], chapterCount: 1, cardCount: 1,
            manifestVersion: 1, manifestPath: "books/\(id)/manifest.json",
            freeForAll: freeForAll, sizeBytes: 0
        )
    }

    @Test("freeForAll book is .free regardless of Pro state")
    func freeForAllAlwaysFree() {
        let service = BookCatalogService(source: MockBookContentSource())
        let book = makeBook(id: "free", freeForAll: true)

        let nonPro = UserProgress()
        #expect(service.lockState(for: book, userProgress: nonPro) == .free)

        let pro = UserProgress()
        pro.isPro = true
        pro.proExpiryDate = Date().addingTimeInterval(60 * 60 * 24)
        #expect(service.lockState(for: book, userProgress: pro) == .free)
    }

    @Test("Non-free book is .locked for non-Pro user")
    func nonFreeLockedWhenNotPro() {
        let service = BookCatalogService(source: MockBookContentSource())
        let book = makeBook(id: "paid", freeForAll: false)
        let user = UserProgress()
        #expect(service.lockState(for: book, userProgress: user) == .locked)
    }

    @Test("Non-free book is .unlocked for active-Pro user")
    func nonFreeUnlockedForPro() {
        let service = BookCatalogService(source: MockBookContentSource())
        let book = makeBook(id: "paid", freeForAll: false)
        let user = UserProgress()
        user.isPro = true
        user.proExpiryDate = Date().addingTimeInterval(60 * 60 * 24)
        #expect(service.lockState(for: book, userProgress: user) == .unlocked)
    }

    @Test("Expired Pro is treated as not-Pro (book locked)")
    func expiredProIsLocked() {
        let service = BookCatalogService(source: MockBookContentSource())
        let book = makeBook(id: "paid", freeForAll: false)
        let user = UserProgress()
        user.isPro = true
        user.proExpiryDate = Date().addingTimeInterval(-60)
        #expect(service.lockState(for: book, userProgress: user) == .locked)
    }
}

@Suite("BookCatalogService — caching behaviour")
@MainActor
struct BookCatalogServiceCacheTests {

    @Test("loadCatalog hits the source once, then serves from cache")
    func cachesAfterFirstLoad() async throws {
        let mock = MockBookContentSource(catalog: BooksCatalog(
            version: 1, updatedAt: Date(), books: []
        ))
        let service = BookCatalogService(source: mock)
        _ = try await service.loadCatalog()
        _ = try await service.loadCatalog()
        _ = try await service.loadCatalog()
        #expect(mock.loadCatalogCalls == 1)
    }

    @Test("refresh() forces a re-fetch")
    func refreshBypassesCache() async throws {
        let mock = MockBookContentSource(catalog: BooksCatalog(
            version: 1, updatedAt: Date(), books: []
        ))
        let service = BookCatalogService(source: mock)
        _ = try await service.loadCatalog()
        _ = try await service.refresh()
        #expect(mock.loadCatalogCalls == 2)
    }
}
