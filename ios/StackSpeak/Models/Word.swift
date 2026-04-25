import Foundation
import SwiftData

@Model
final class Word {
    @Attribute(.unique) var id: UUID
    var word: String
    var pronunciation: String
    var partOfSpeech: String
    var shortDefinition: String
    var simpleDefinition: String = ""
    var longDefinition: String
    var techContext: String
    var exampleSentence: String
    var etymology: String
    var connector: String = ""
    var codeExampleLanguage: String
    var codeExampleCode: String
    /// Stored as the stack's raw id (e.g. "basic-web"). Use `wordStack` for a typed view.
    var stack: String
    var unlockLevel: Int
    var tags: [String]

    var wordStack: WordStack { WordStack(rawValue: stack) }

    init(
        id: UUID,
        word: String,
        pronunciation: String,
        partOfSpeech: String,
        shortDefinition: String,
        simpleDefinition: String,
        longDefinition: String,
        techContext: String,
        exampleSentence: String,
        etymology: String,
        connector: String,
        codeExampleLanguage: String,
        codeExampleCode: String,
        stack: String,
        unlockLevel: Int,
        tags: [String]
    ) {
        self.id = id
        self.word = word
        self.pronunciation = pronunciation
        self.partOfSpeech = partOfSpeech
        self.shortDefinition = shortDefinition
        self.simpleDefinition = simpleDefinition
        self.longDefinition = longDefinition
        self.techContext = techContext
        self.exampleSentence = exampleSentence
        self.etymology = etymology
        self.connector = connector
        self.codeExampleLanguage = codeExampleLanguage
        self.codeExampleCode = codeExampleCode
        self.stack = stack
        self.unlockLevel = unlockLevel
        self.tags = tags
    }

    convenience init(from dto: WordDTO, stack: String) {
        self.init(
            id: UUID(uuidString: dto.id) ?? deterministicUUID(from: dto.id),
            word: dto.word,
            pronunciation: dto.pronunciation,
            partOfSpeech: dto.partOfSpeech,
            shortDefinition: dto.shortDefinition,
            simpleDefinition: dto.simpleDefinition,
            longDefinition: dto.longDefinition,
            techContext: dto.techContext,
            exampleSentence: dto.exampleSentence,
            etymology: dto.etymology,
            connector: dto.connector,
            codeExampleLanguage: dto.codeExample?.language ?? "",
            codeExampleCode: dto.codeExample?.code ?? "",
            stack: stack,
            unlockLevel: dto.unlockLevel,
            tags: dto.tags
        )
    }
}

/// Converts an arbitrary string to a deterministic UUID via FNV-1a so that
/// mnemonic IDs like "bw001000-…" always produce the same UUID across installs.
func deterministicUUID(from string: String) -> UUID {
    var h1: UInt64 = 14695981039346656037
    var h2: UInt64 = 14695981039346656037 &+ 1
    for byte in string.utf8 {
        h1 ^= UInt64(byte)
        h1 = h1 &* 1099511628211
        h2 ^= UInt64(byte)
        h2 = h2 &* 1099511628211 &+ 7
    }
    func byte(_ h: UInt64, _ shift: Int) -> UInt8 { UInt8((h >> shift) & 0xFF) }
    let uuid: uuid_t = (
        byte(h1,  0), byte(h1,  8), byte(h1, 16), byte(h1, 24),
        byte(h1, 32), byte(h1, 40), byte(h1, 48), byte(h1, 56),
        byte(h2,  0), byte(h2,  8), byte(h2, 16), byte(h2, 24),
        byte(h2, 32), byte(h2, 40), byte(h2, 48), byte(h2, 56)
    )
    return UUID(uuid: uuid)
}

// MARK: - DTO (matches words.json wire format)

struct WordDTO: Codable {
    let id: String  // may be a valid UUID string or a mnemonic like "bw001000-…"
    let word: String
    let pronunciation: String
    let partOfSpeech: String
    let shortDefinition: String
    let simpleDefinition: String
    let longDefinition: String
    let techContext: String
    let exampleSentence: String
    let etymology: String
    let connector: String
    let codeExample: CodeExampleDTO?
    let unlockLevel: Int
    let tags: [String]
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
        techContext = try c.decode(String.self, forKey: .techContext)
        exampleSentence = try c.decode(String.self, forKey: .exampleSentence)
        etymology = try c.decode(String.self, forKey: .etymology)
        connector = try c.decodeIfPresent(String.self, forKey: .connector) ?? ""
        codeExample = try c.decodeIfPresent(CodeExampleDTO.self, forKey: .codeExample)
        unlockLevel = try c.decode(Int.self, forKey: .unlockLevel)
        tags = try c.decode([String].self, forKey: .tags)
    }
}

struct CodeExampleDTO: Codable {
    let language: String?
    let code: String?
}

struct WordsDatabaseDTO: Codable {
    let words: [WordDTO]
}

// MARK: - Stack file DTO

struct StackFileDTO: Codable {
    let stack: String
    let words: [WordDTO]
}
