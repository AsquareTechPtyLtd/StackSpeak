import Foundation

// MARK: - Word wire-format DTOs (matches words.json / stack files)
// Co-located: these four types are one decoding pipeline — StackFileDTO wraps
// WordDTO rows, which nest CodeExampleDTO/BackingCardRef. Splitting them one
// per file would scatter a single wire format across five files.

struct WordDTO: Codable {
    let id: String  // may be a valid UUID string or a mnemonic like "bw001000-…"
    let word: String
    let pronunciation: String
    let partOfSpeech: String
    let shortDefinition: String
    let simpleDefinition: String
    let longDefinition: String
    let techContext: String
    /// Used by soft-skills words instead of techContext. Empty for technical words.
    let professionalContext: String
    let exampleSentence: String
    let etymology: String
    let connector: String
    let codeExample: CodeExampleDTO?
    let backingCard: BackingCardRef?
    let unlockLevel: Int
    let tags: [String]
    let category: String
    // `stack` is intentionally absent — it is injected from StackFileDTO.stack by the loader.

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        word = try c.decode(String.self, forKey: .word)
        pronunciation = try c.decode(String.self, forKey: .pronunciation)
        partOfSpeech = try c.decode(String.self, forKey: .partOfSpeech)
        shortDefinition = try c.decode(String.self, forKey: .shortDefinition)
        simpleDefinition = try c.decodeIfPresent(String.self, forKey: .simpleDefinition) ?? ""
        longDefinition = try c.decode(String.self, forKey: .longDefinition)
        // techContext / professionalContext / exampleSentence / etymology are tolerant:
        // every UI surface already gates on `.isEmpty` before rendering them, so a word
        // missing one of these still loads (it just doesn't render that section).
        // Same pattern as simpleDefinition / connector.
        techContext = try c.decodeIfPresent(String.self, forKey: .techContext) ?? ""
        professionalContext = try c.decodeIfPresent(String.self, forKey: .professionalContext) ?? ""
        exampleSentence = try c.decodeIfPresent(String.self, forKey: .exampleSentence) ?? ""
        etymology = try c.decodeIfPresent(String.self, forKey: .etymology) ?? ""
        connector = try c.decodeIfPresent(String.self, forKey: .connector) ?? ""
        codeExample = try c.decodeIfPresent(CodeExampleDTO.self, forKey: .codeExample)
        backingCard = try c.decodeIfPresent(BackingCardRef.self, forKey: .backingCard)
        unlockLevel = try c.decode(Int.self, forKey: .unlockLevel)
        tags = try c.decode([String].self, forKey: .tags)
        // Open vocabulary — any category string is accepted (defaults to "concepts").
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "concepts"
    }
}

struct CodeExampleDTO: Codable {
    let language: String?
    let code: String?
}

/// Reference to the book card a word was authored from. `chapterId`/`cardId` are
/// optional: ~all book-backed words resolve a chapter; an exact card is a bonus.
struct BackingCardRef: Codable, Hashable {
    let bookId: String
    let chapterId: String?
    let cardId: String?
}

struct WordsDatabaseDTO: Codable {
    let words: [WordDTO]
}

// MARK: - Stack file DTO

struct StackFileDTO: Codable {
    let stack: String
    let words: [WordDTO]
}
