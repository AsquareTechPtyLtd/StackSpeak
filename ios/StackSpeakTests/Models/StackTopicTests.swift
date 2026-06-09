import Testing
import Foundation
@testable import StackSpeak

@Suite("StackTopic — tolerant decode")
struct StackTopicTests {

    /// Builds a StackDefinition JSON with an optional `category` field.
    private func json(category: String?) -> String {
        let cat = category.map { ",\"category\":\"\($0)\"" } ?? ""
        return "{\"id\":\"x\",\"name\":\"X\",\"file\":\"stacks/x.json\",\"wordCount\":1,"
            + "\"description\":\"d\",\"icon\":\"book\",\"minimumLevel\":1,\"isMandatory\":false\(cat)}"
    }

    private func decode(_ category: String?) throws -> StackDefinition {
        try JSONDecoder().decode(StackDefinition.self, from: Data(json(category: category).utf8))
    }

    @Test("known category decodes to its case (incl. hyphenated raw values)")
    func knownCategory() throws {
        #expect(try decode("security").category == .security)
        #expect(try decode("ai-ml").category == .aiml)
        #expect(try decode("devops-sre").category == .devopsSre)
        #expect(try decode("architecture").category == .architecture)
    }

    @Test("unknown category falls back to .other")
    func unknownCategory() throws {
        #expect(try decode("quantum-computing").category == .other)
    }

    @Test("missing category falls back to .other")
    func missingCategory() throws {
        #expect(try decode(nil).category == .other)
    }

    @Test("every StackTopic has a unique sort order")
    func sortOrdersUnique() {
        let orders = StackTopic.allCases.map(\.sortOrder)
        #expect(Set(orders).count == StackTopic.allCases.count)
    }
}
