import Foundation

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
