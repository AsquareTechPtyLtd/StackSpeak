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

    private enum CodingKeys: String, CodingKey {
        case id, order, title, teaser, explanation, feynman
        // Legacy vocabulary-card fields (effective-python ch02/ch03).
        case word, definition, examples
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0

        if c.contains(.word) {
            // Adapt a legacy vocabulary card into a teaching card: word → title,
            // definition → teaser + lead paragraph, each example → an info callout.
            let word = try c.decode(String.self, forKey: .word)
            let definition = try c.decodeIfPresent(String.self, forKey: .definition) ?? ""
            let examples = try c.decodeIfPresent([VocabExample].self, forKey: .examples) ?? []
            title = word
            teaser = definition.isEmpty ? word : BookCard.firstSentence(of: definition)
            var blocks: [ContentBlock] = []
            if !definition.isEmpty {
                blocks.append(.paragraph(runs: [InlineRun(text: definition)]))
            }
            for example in examples {
                var runs: [InlineRun] = []
                if !example.context.isEmpty {
                    runs.append(InlineRun(text: example.context + " — ", marks: [.bold]))
                }
                runs.append(InlineRun(text: example.sentence))
                blocks.append(.callout(variant: .info, runs: runs))
            }
            explanation = blocks
            feynman = []
        } else {
            // Standard teaching card. Legacy content occasionally omits
            // explanation/feynman; treat a missing block list as empty.
            title = try c.decode(String.self, forKey: .title)
            teaser = try c.decode(String.self, forKey: .teaser)
            explanation = try c.decodeIfPresent([ContentBlock].self, forKey: .explanation) ?? []
            feynman = try c.decodeIfPresent([ContentBlock].self, forKey: .feynman) ?? []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(order, forKey: .order)
        try c.encode(title, forKey: .title)
        try c.encode(teaser, forKey: .teaser)
        try c.encode(explanation, forKey: .explanation)
        try c.encode(feynman, forKey: .feynman)
    }

    /// First sentence of `text` (through the first ". "), for a vocab card's teaser.
    private static func firstSentence(of text: String) -> String {
        if let r = text.range(of: ". ") {
            return String(text[..<r.lowerBound]) + "."
        }
        return text
    }
}

/// Decode-only helper for a legacy vocabulary card's `examples` entries.
private struct VocabExample: Decodable {
    let context: String
    let sentence: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        context = try c.decodeIfPresent(String.self, forKey: .context) ?? ""
        sentence = try c.decodeIfPresent(String.self, forKey: .sentence) ?? ""
    }

    private enum CodingKeys: String, CodingKey { case context, sentence }
}

/// Decoded shape of a chapter shard file (e.g. `chapters/ch01.json`).
/// One chapter may be split across multiple shards — the loader concatenates them
/// in `shardIndex` order to produce the full ordered card list.
struct BookChapterShard: Codable, Sendable {
    let chapterId: String
    let shardIndex: Int
    let cards: [BookCard]
}
