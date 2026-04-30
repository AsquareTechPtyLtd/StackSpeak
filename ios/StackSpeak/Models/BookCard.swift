import Foundation

/// A single bite-sized teaching card inside a book chapter.
/// Hydrated on chapter open from a chapter shard JSON file. Never persisted to SwiftData —
/// content lives in files, only user state lives in the database.
struct BookCard: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let order: Int
    let title: String
    let teaser: String
    let explanation: [ContentBlock]
    let feynman: [ContentBlock]
}

/// Decoded shape of a chapter shard file (e.g. `chapters/ch01.json`).
/// One chapter may be split across multiple shards — the loader concatenates them
/// in `shardIndex` order to produce the full ordered card list.
struct BookChapterShard: Codable, Sendable {
    let chapterId: String
    let shardIndex: Int
    let cards: [BookCard]
}
