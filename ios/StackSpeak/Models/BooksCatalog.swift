import Foundation

/// One entry in the global books catalog. Lightweight — does not include chapter
/// or card content. Loaded on app launch so the Books tab can render the catalog
/// without touching per-book content.
///
/// `freeForAll: true` appears on **exactly one book at a time** and overrides Pro gating.
/// Swappable without a code change by editing `books-catalog.json`.
struct BookSummary: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let author: String?
    let summary: String
    let coverIcon: String
    let accentHex: String?
    let tags: [String]
    let chapterCount: Int
    let cardCount: Int
    let manifestVersion: Int
    let manifestPath: String
    let freeForAll: Bool
    let sizeBytes: Int
}

/// Top-level catalog file shape — bundled today, refreshable later.
struct BooksCatalog: Codable, Sendable, Hashable {
    let version: Int
    let updatedAt: Date
    let books: [BookSummary]
}
