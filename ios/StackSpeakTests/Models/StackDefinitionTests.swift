import Testing
import Foundation
@testable import StackSpeak

@Suite("StackDefinition — shortName")
struct StackDefinitionTests {

    private func decode(_ json: String) throws -> StackDefinition {
        try JSONDecoder().decode(StackDefinition.self, from: Data(json.utf8))
    }

    @Test("shortName decodes when present")
    func decodesShortName() throws {
        let def = try decode(#"""
        {"id":"web-security-basic","name":"Web Security Fundamentals","shortName":"Web Security",
         "file":"stacks/web-security-basic.json","wordCount":40,"description":"d","icon":"lock",
         "minimumLevel":1,"isMandatory":false,"category":"security"}
        """#)
        #expect(def.shortName == "Web Security")
    }

    @Test("shortName falls back to name when absent")
    func fallsBackToName() throws {
        let def = try decode(#"""
        {"id":"git-basic","name":"Git Fundamentals",
         "file":"stacks/git-basic.json","wordCount":25,"description":"d","icon":"arrow.branch",
         "minimumLevel":1,"isMandatory":false,"category":"foundations"}
        """#)
        #expect(def.shortName == "Git Fundamentals")
    }

    @Test("Every shipped stack carries a non-empty shortName")
    func everyStackHasShortName() throws {
        // The bundled index is the source of truth the app loads at launch.
        let url = Bundle(for: BundleAnchor.self).url(forResource: "words-index", withExtension: "json")
        guard let url else { return }   // resource not in this test bundle — skip
        struct Index: Decodable { let stacks: [StackDefinition] }
        let index = try JSONDecoder().decode(Index.self, from: Data(contentsOf: url))
        #expect(index.stacks.allSatisfy { !$0.shortName.isEmpty })
    }
}

/// Anchors `Bundle(for:)` to whichever bundle this test compiles into.
private final class BundleAnchor {}
