import Foundation

/// Top-level catalog file shape — bundled today, refreshable later.
struct BooksCatalog: Codable, Sendable, Hashable {
    let version: Int
    let updatedAt: Date
    let books: [BookSummary]
}
