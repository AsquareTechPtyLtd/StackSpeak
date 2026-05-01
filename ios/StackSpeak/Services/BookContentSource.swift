import Foundation

/// Pluggable source of book catalog + per-book content. The MVP ships
/// `BundledBookSource` (reads from `Bundle.main`); Phase 7 swaps in
/// `RemoteBookSource` without UI / state changes.
protocol BookContentSource: Sendable {
    func loadCatalog() async throws -> BooksCatalog
    func loadManifest(bookId: String) async throws -> BookManifest
    func loadChapter(bookId: String, chapterId: String, shards: [String]) async throws -> [BookCard]
}

enum BookContentError: LocalizedError {
    case catalogNotFound
    case catalogDecodeFailed(any Error)
    case manifestNotFound(bookId: String)
    case manifestDecodeFailed(bookId: String, underlying: any Error)
    case manifestIdMismatch(catalogId: String, manifestId: String)
    case chapterShardNotFound(bookId: String, shard: String)
    case chapterShardDecodeFailed(bookId: String, shard: String, underlying: any Error)
    case chapterIdMismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .catalogNotFound:
            return "books-catalog.json not found in bundle"
        case .catalogDecodeFailed(let error):
            return "books-catalog.json failed to decode: \(error.localizedDescription)"
        case .manifestNotFound(let bookId):
            return "manifest.json not found for book \(bookId)"
        case .manifestDecodeFailed(let bookId, let error):
            return "manifest.json for \(bookId) failed to decode: \(error.localizedDescription)"
        case .manifestIdMismatch(let catalogId, let manifestId):
            return "manifest id \(manifestId) does not match catalog entry \(catalogId)"
        case .chapterShardNotFound(let bookId, let shard):
            return "chapter shard \(shard) not found for book \(bookId)"
        case .chapterShardDecodeFailed(let bookId, let shard, let error):
            return "chapter shard \(shard) for \(bookId) failed to decode: \(error.localizedDescription)"
        case .chapterIdMismatch(let expected, let actual):
            return "chapter shard id \(actual) does not match expected \(expected)"
        }
    }
}
