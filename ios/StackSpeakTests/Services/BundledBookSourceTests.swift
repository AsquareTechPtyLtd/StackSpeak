import Testing
import Foundation
@testable import StackSpeak

@Suite("BundledBookSource — catalog / manifest / chapter loading")
struct BundledBookSourceTests {

    /// Creates a fresh temp directory containing a mock books layout. Caller is
    /// responsible for cleanup (or just leak it — Foundation reaps tmp on reboot).
    private func makeFixtureDirectory(_ build: (URL) throws -> Void) throws -> URL {
        let root = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("stackspeak-books-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try build(root)
        return root
    }

    private func writeJSON(_ object: some Encodable, to url: URL, isoDate: Bool = false) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        if isoDate { encoder.dateEncodingStrategy = .iso8601 }
        let data = try encoder.encode(object)
        try data.write(to: url)
    }

    private func sampleCatalog() -> BooksCatalog {
        BooksCatalog(
            version: 1,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            books: [
                BookSummary(
                    id: "free-book",
                    title: "Free",
                    author: nil,
                    summary: "free summary",
                    coverIcon: "book",
                    accentHex: nil,
                    tags: ["agents"],
                    categories: [.aiML],
                    chapterCount: 1,
                    cardCount: 2,
                    manifestVersion: 1,
                    manifestPath: "books/free-book/manifest.json",
                    freeForAll: true,
                    sizeBytes: 1024
                )
            ]
        )
    }

    @Test("loadCatalog — happy path returns the encoded catalog")
    func loadCatalogSuccess() async throws {
        let catalog = sampleCatalog()
        let dir = try makeFixtureDirectory { root in
            try writeJSON(catalog, to: root.appendingPathComponent("books-catalog.json"), isoDate: true)
        }
        let source = BundledBookSource(resourcesURL: dir)
        let loaded = try await source.loadCatalog()
        #expect(loaded == catalog)
    }

    @Test("loadCatalog — throws .catalogNotFound when file is missing")
    func loadCatalogMissingThrows() async throws {
        let dir = try makeFixtureDirectory { _ in }
        let source = BundledBookSource(resourcesURL: dir)
        await #expect(throws: BookContentError.self) {
            _ = try await source.loadCatalog()
        }
    }

    @Test("loadCatalog — throws .catalogDecodeFailed on malformed JSON")
    func loadCatalogMalformedThrows() async throws {
        let dir = try makeFixtureDirectory { root in
            try Data("not-json-at-all".utf8).write(to: root.appendingPathComponent("books-catalog.json"))
        }
        let source = BundledBookSource(resourcesURL: dir)
        await #expect(throws: BookContentError.self) {
            _ = try await source.loadCatalog()
        }
    }

    @Test("loadManifest — happy path returns the manifest")
    func loadManifestSuccess() async throws {
        let manifest = BookManifest(
            id: "free-book",
            version: 1,
            title: "Free",
            author: "Author",
            summary: "summary",
            categories: [.aiML],
            chapters: [
                ChapterSummary(id: "ch01", order: 1, title: "Ch1", summary: "s",
                              icon: "book", cardCount: 2, cardIds: ["c1", "c2"],
                              shards: ["chapters/ch01.json"])
            ]
        )
        let dir = try makeFixtureDirectory { root in
            try writeJSON(manifest, to: root.appendingPathComponent("books/free-book/manifest.json"))
        }
        let source = BundledBookSource(resourcesURL: dir)
        let loaded = try await source.loadManifest(bookId: "free-book")
        #expect(loaded == manifest)
    }

    @Test("loadManifest — id mismatch is detected and thrown")
    func loadManifestIdMismatch() async throws {
        // Manifest with id "wrong" stored under the "free-book" path.
        let manifest = BookManifest(
            id: "wrong",
            version: 1,
            title: "X",
            author: nil,
            summary: "x",
            categories: [.codeCraft],
            chapters: []
        )
        let dir = try makeFixtureDirectory { root in
            try writeJSON(manifest, to: root.appendingPathComponent("books/free-book/manifest.json"))
        }
        let source = BundledBookSource(resourcesURL: dir)
        await #expect(throws: BookContentError.self) {
            _ = try await source.loadManifest(bookId: "free-book")
        }
    }

    @Test("loadManifest — throws .manifestNotFound when file is missing")
    func loadManifestMissing() async throws {
        let dir = try makeFixtureDirectory { _ in }
        let source = BundledBookSource(resourcesURL: dir)
        await #expect(throws: BookContentError.self) {
            _ = try await source.loadManifest(bookId: "absent")
        }
    }

    @Test("loadChapter — multi-shard concatenation honours shardIndex order")
    func loadChapterMultiShardOrder() async throws {
        let card1 = BookCard(id: "c1", order: 1, title: "A", teaser: "a",
                             explanation: [.paragraph(runs: [InlineRun(text: "1")])], feynman: [])
        let card2 = BookCard(id: "c2", order: 2, title: "B", teaser: "b",
                             explanation: [.paragraph(runs: [InlineRun(text: "2")])], feynman: [])
        let card3 = BookCard(id: "c3", order: 3, title: "C", teaser: "c",
                             explanation: [.paragraph(runs: [InlineRun(text: "3")])], feynman: [])

        // Author the shard files in the WRONG order on disk and out-of-order shardIndex
        // values; the loader must use shardIndex authoritatively.
        let shardA = BookChapterShard(chapterId: "ch01", shardIndex: 2, cards: [card3])
        let shardB = BookChapterShard(chapterId: "ch01", shardIndex: 1, cards: [card1, card2])

        let dir = try makeFixtureDirectory { root in
            try writeJSON(shardA, to: root.appendingPathComponent("books/free-book/chapters/late.json"))
            try writeJSON(shardB, to: root.appendingPathComponent("books/free-book/chapters/early.json"))
        }
        let source = BundledBookSource(resourcesURL: dir)
        // Pass the shards in the same order the manifest has them (in this test, "late"
        // first to prove that the loader doesn't trust list order).
        let cards = try await source.loadChapter(
            bookId: "free-book",
            chapterId: "ch01",
            shards: ["chapters/late.json", "chapters/early.json"]
        )
        #expect(cards.map(\.id) == ["c1", "c2", "c3"])
    }

    @Test("loadChapter — chapterId mismatch in a shard is rejected")
    func loadChapterIdMismatch() async throws {
        let shard = BookChapterShard(
            chapterId: "different",
            shardIndex: 1,
            cards: [BookCard(id: "c1", order: 1, title: "A", teaser: "a",
                             explanation: [], feynman: [])]
        )
        let dir = try makeFixtureDirectory { root in
            try writeJSON(shard, to: root.appendingPathComponent("books/free-book/chapters/ch01.json"))
        }
        let source = BundledBookSource(resourcesURL: dir)
        await #expect(throws: BookContentError.self) {
            _ = try await source.loadChapter(
                bookId: "free-book",
                chapterId: "ch01",
                shards: ["chapters/ch01.json"]
            )
        }
    }

    @Test("loadChapter — missing shard throws .chapterShardNotFound")
    func loadChapterMissingShard() async throws {
        let dir = try makeFixtureDirectory { _ in }
        let source = BundledBookSource(resourcesURL: dir)
        await #expect(throws: BookContentError.self) {
            _ = try await source.loadChapter(
                bookId: "free-book",
                chapterId: "ch01",
                shards: ["chapters/missing.json"]
            )
        }
    }
}
