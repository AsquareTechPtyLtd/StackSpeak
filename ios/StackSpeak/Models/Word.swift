import Foundation
import SwiftData

/// Interleaving categories for cognitive variety
enum WordCategory: String, Codable {
    case concepts        // Abstract ideas & principles (idempotent, polymorphism)
    case components      // Concrete building blocks (pod, hook, container)
    case processes       // Actions & workflows (reconciliation, sharding, articulate)
    case patterns        // Repeatable approaches (singleton, observer, scrum)
    case qualities       // Properties & characteristics (stateless, concise, distributed)

    var emoji: String {
        switch self {
        case .concepts: return "🔵"
        case .components: return "🟢"
        case .processes: return "🟠"
        case .patterns: return "🟣"
        case .qualities: return "🔴"
        }
    }

    var displayName: String {
        switch self {
        case .concepts: return "Concepts"
        case .components: return "Components"
        case .processes: return "Processes"
        case .patterns: return "Patterns"
        case .qualities: return "Qualities"
        }
    }
}

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
    /// Used by soft-skills words instead of techContext. Empty for technical words.
    var professionalContext: String = ""
    var exampleSentence: String
    var etymology: String
    var connector: String = ""
    var codeExampleLanguage: String
    var codeExampleCode: String
    /// Stored as the stack's raw id (e.g. "basic-web"). Use `wordStack` for a typed view.
    var stack: String
    var unlockLevel: Int
    var tagsStorage: String
    /// Interleaving category for daily variety
    var categoryRaw: String = WordCategory.concepts.rawValue

    var tags: [String] {
        get { tagsStorage.isEmpty ? [] : tagsStorage.components(separatedBy: ",") }
        set { tagsStorage = newValue.joined(separator: ",") }
    }

    var wordStack: WordStack { WordStack(rawValue: stack) }
    var category: WordCategory {
        get { WordCategory(rawValue: categoryRaw) ?? .concepts }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: UUID,
        word: String,
        pronunciation: String,
        partOfSpeech: String,
        shortDefinition: String,
        simpleDefinition: String,
        longDefinition: String,
        techContext: String,
        professionalContext: String = "",
        exampleSentence: String,
        etymology: String,
        connector: String,
        codeExampleLanguage: String,
        codeExampleCode: String,
        stack: String,
        unlockLevel: Int,
        tags: [String],
        category: WordCategory = .concepts
    ) {
        self.id = id
        self.word = word
        self.pronunciation = pronunciation
        self.partOfSpeech = partOfSpeech
        self.shortDefinition = shortDefinition
        self.simpleDefinition = simpleDefinition
        self.longDefinition = longDefinition
        self.techContext = techContext
        self.professionalContext = professionalContext
        self.exampleSentence = exampleSentence
        self.etymology = etymology
        self.connector = connector
        self.codeExampleLanguage = codeExampleLanguage
        self.codeExampleCode = codeExampleCode
        self.stack = stack
        self.unlockLevel = unlockLevel
        self.tagsStorage = tags.joined(separator: ",")
        self.categoryRaw = category.rawValue
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
            professionalContext: dto.professionalContext,
            exampleSentence: dto.exampleSentence,
            etymology: dto.etymology,
            connector: dto.connector,
            codeExampleLanguage: dto.codeExample?.language ?? "",
            codeExampleCode: dto.codeExample?.code ?? "",
            stack: stack,
            unlockLevel: dto.unlockLevel,
            tags: dto.tags,
            category: dto.category
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
    /// Used by soft-skills words instead of techContext. Empty for technical words.
    let professionalContext: String
    let exampleSentence: String
    let etymology: String
    let connector: String
    let codeExample: CodeExampleDTO?
    let unlockLevel: Int
    let tags: [String]
    let category: WordCategory
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
        unlockLevel = try c.decode(Int.self, forKey: .unlockLevel)
        tags = try c.decode([String].self, forKey: .tags)
        // Default to concepts if not specified (for backwards compatibility)
        category = try c.decodeIfPresent(WordCategory.self, forKey: .category) ?? .concepts
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
