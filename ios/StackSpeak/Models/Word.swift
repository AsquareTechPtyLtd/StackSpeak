import Foundation
import SwiftData

@Model
final class Word {
    @Attribute(.unique) var id: UUID
    var word: String
    var pronunciation: String
    var partOfSpeech: String
    var shortDefinition: String
    var longDefinition: String
    var techContext: String
    var exampleSentence: String
    var etymology: String
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
        longDefinition: String,
        techContext: String,
        exampleSentence: String,
        etymology: String,
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
        self.longDefinition = longDefinition
        self.techContext = techContext
        self.exampleSentence = exampleSentence
        self.etymology = etymology
        self.codeExampleLanguage = codeExampleLanguage
        self.codeExampleCode = codeExampleCode
        self.stack = stack
        self.unlockLevel = unlockLevel
        self.tags = tags
    }

    convenience init(from dto: WordDTO, stack: String) {
        self.init(
            id: dto.id,
            word: dto.word,
            pronunciation: dto.pronunciation,
            partOfSpeech: dto.partOfSpeech,
            shortDefinition: dto.shortDefinition,
            longDefinition: dto.longDefinition,
            techContext: dto.techContext,
            exampleSentence: dto.exampleSentence,
            etymology: dto.etymology,
            codeExampleLanguage: dto.codeExample.language,
            codeExampleCode: dto.codeExample.code,
            stack: stack,
            unlockLevel: dto.unlockLevel,
            tags: dto.tags
        )
    }
}

// MARK: - DTO (matches words.json wire format)

struct WordDTO: Codable {
    let id: UUID
    let word: String
    let pronunciation: String
    let partOfSpeech: String
    let shortDefinition: String
    let longDefinition: String
    let techContext: String
    let exampleSentence: String
    let etymology: String
    let codeExample: CodeExampleDTO
    let unlockLevel: Int
    let tags: [String]
    // `stack` is intentionally absent — it is injected from StackFileDTO.stack by the loader.
}

struct CodeExampleDTO: Codable {
    let language: String
    let code: String
}

struct WordsDatabaseDTO: Codable {
    let words: [WordDTO]
}

// MARK: - Stack file DTO

struct StackFileDTO: Codable {
    let stack: String
    let words: [WordDTO]
}
