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

    init(id: String, order: Int, title: String, teaser: String,
         explanation: [ContentBlock], feynman: [ContentBlock]) {
        self.id = id
        self.order = order
        self.title = title
        self.teaser = teaser
        self.explanation = explanation
        self.feynman = feynman
    }

    // Legacy content occasionally omits `explanation`/`feynman` on a card; treat a
    // missing block list as empty rather than failing the whole chapter's decode.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        order = try c.decode(Int.self, forKey: .order)
        title = try c.decode(String.self, forKey: .title)
        teaser = try c.decode(String.self, forKey: .teaser)
        explanation = try c.decodeIfPresent([ContentBlock].self, forKey: .explanation) ?? []
        feynman = try c.decodeIfPresent([ContentBlock].self, forKey: .feynman) ?? []
    }
}

/// Decoded shape of a chapter shard file (e.g. `chapters/ch01.json`).
/// One chapter may be split across multiple shards — the loader concatenates them
/// in `shardIndex` order to produce the full ordered card list.
struct BookChapterShard: Codable, Sendable {
    let chapterId: String
    let shardIndex: Int
    let cards: [BookCard]
}
