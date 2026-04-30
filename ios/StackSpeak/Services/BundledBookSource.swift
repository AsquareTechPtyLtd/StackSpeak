import Foundation

/// MVP `BookContentSource` that reads catalog, manifests, and chapter shards from disk —
/// either the app bundle (production) or any directory URL (tests, fixtures).
///
/// Phase 7 adds `RemoteBookSource` with a CDN-backed cache; the swap is transparent
/// to ViewModels because both implementations conform to `BookContentSource`.
final class BundledBookSource: BookContentSource, @unchecked Sendable {
    private let resourcesURL: URL
    private let catalogFileName: String
    private let booksDirectoryName: String

    init(
        resourcesURL: URL,
        catalogFileName: String = "books-catalog.json",
        booksDirectoryName: String = "books"
    ) {
        self.resourcesURL = resourcesURL
        self.catalogFileName = catalogFileName
        self.booksDirectoryName = booksDirectoryName
    }

    /// Convenience: reads from `Bundle.main.resourceURL` (or the bundle URL if resources
    /// are not in a separate folder, e.g. on macOS test bundles).
    static func main() -> BundledBookSource {
        let url = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        return BundledBookSource(resourcesURL: url)
    }

    nonisolated(unsafe) private static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func loadCatalog() async throws -> BooksCatalog {
        let url = resourcesURL.appendingPathComponent(catalogFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw BookContentError.catalogNotFound
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BookContentError.catalogNotFound
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let date = Self.iso8601WithFractional.date(from: raw) { return date }
            if let date = Self.iso8601Plain.date(from: raw) { return date }
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unrecognized ISO8601 date: \(raw)"
            ))
        }
        do {
            return try decoder.decode(BooksCatalog.self, from: data)
        } catch {
            throw BookContentError.catalogDecodeFailed(error)
        }
    }

    func loadManifest(bookId: String) async throws -> BookManifest {
        let url = resourcesURL.appendingPathComponent("\(booksDirectoryName)/\(bookId)/manifest.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw BookContentError.manifestNotFound(bookId: bookId)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BookContentError.manifestNotFound(bookId: bookId)
        }
        let manifest: BookManifest
        do {
            manifest = try JSONDecoder().decode(BookManifest.self, from: data)
        } catch {
            throw BookContentError.manifestDecodeFailed(bookId: bookId, underlying: error)
        }
        guard manifest.id == bookId else {
            throw BookContentError.manifestIdMismatch(catalogId: bookId, manifestId: manifest.id)
        }
        return manifest
    }

    func loadChapter(bookId: String, chapterId: String, shards: [String]) async throws -> [BookCard] {
        var collected: [(shardIndex: Int, cards: [BookCard])] = []

        for shard in shards {
            let url = resourcesURL.appendingPathComponent("\(booksDirectoryName)/\(bookId)/\(shard)")
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw BookContentError.chapterShardNotFound(bookId: bookId, shard: shard)
            }
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw BookContentError.chapterShardNotFound(bookId: bookId, shard: shard)
            }
            let decoded: BookChapterShard
            do {
                decoded = try JSONDecoder().decode(BookChapterShard.self, from: data)
            } catch {
                throw BookContentError.chapterShardDecodeFailed(bookId: bookId, shard: shard, underlying: error)
            }
            guard decoded.chapterId == chapterId else {
                throw BookContentError.chapterIdMismatch(expected: chapterId, actual: decoded.chapterId)
            }
            collected.append((decoded.shardIndex, decoded.cards))
        }

        // shardIndex ordering is authoritative; card order within each shard preserved.
        return collected
            .sorted { $0.shardIndex < $1.shardIndex }
            .flatMap { $0.cards }
    }
}
