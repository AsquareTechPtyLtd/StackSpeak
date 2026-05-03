import Foundation

/// Per-chapter metadata referenced by a `BookManifest`.
/// `shards` lists the chapter-shard files (relative to the book's root directory)
/// that hold the chapter's cards.
///
/// `cardIds` is the ordered list of card IDs in this chapter — duplicated in the
/// manifest so the Book Detail screen can compute `X / N` completion without
/// loading each chapter's full content shards. The build tool populates it.
struct ChapterSummary: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let order: Int
    let title: String
    let summary: String
    let icon: String
    let cardCount: Int
    let cardIds: [String]
    let shards: [String]
}

/// Per-book manifest: title, summary, and the ordered chapter list.
/// Loaded once when the user opens a book; chapter content is fetched lazily.
struct BookManifest: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let version: Int
    let title: String
    let author: String?
    let summary: String
    /// Locked taxonomy of categories — duplicated from the catalog so a manifest
    /// is self-describing if loaded directly.
    let categories: [BookCategory]
    let chapters: [ChapterSummary]
}
