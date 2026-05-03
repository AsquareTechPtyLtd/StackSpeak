import Testing
import Foundation
@testable import StackSpeak

@Suite("ContentBlock — Codable roundtrip")
struct ContentBlockCodableTests {

    private func roundtrip(_ block: ContentBlock) throws -> ContentBlock {
        let data = try JSONEncoder().encode(block)
        return try JSONDecoder().decode(ContentBlock.self, from: data)
    }

    @Test("paragraph with mixed inline marks survives roundtrip")
    func paragraphRoundtrip() throws {
        let block = ContentBlock.paragraph(runs: [
            InlineRun(text: "An "),
            InlineRun(text: "agent", marks: [.bold]),
            InlineRun(text: " "),
            InlineRun(text: "decides", marks: [.italic]),
            InlineRun(text: " what to "),
            InlineRun(text: "run", marks: [.code]),
            InlineRun(text: " — see "),
            InlineRun(text: "docs", marks: [.link], href: "https://example.com")
        ])
        let restored = try roundtrip(block)
        #expect(restored == block)
    }

    @Test("heading levels 2 and 3 survive roundtrip")
    func headingRoundtrip() throws {
        let h2 = ContentBlock.heading(level: 2, text: "Section")
        let h3 = ContentBlock.heading(level: 3, text: "Subsection")
        #expect(try roundtrip(h2) == h2)
        #expect(try roundtrip(h3) == h3)
    }

    @Test("bulleted and numbered lists survive roundtrip")
    func listsRoundtrip() throws {
        let bulleted = ContentBlock.list(style: .bulleted, items: [
            [InlineRun(text: "one")],
            [InlineRun(text: "two")]
        ])
        let numbered = ContentBlock.list(style: .numbered, items: [
            [InlineRun(text: "first", marks: [.bold])],
            [InlineRun(text: "second")]
        ])
        #expect(try roundtrip(bulleted) == bulleted)
        #expect(try roundtrip(numbered) == numbered)
    }

    @Test("code block preserves language and verbatim code")
    func codeRoundtrip() throws {
        let block = ContentBlock.code(language: "swift", code: "let x = 1\nprint(x)")
        #expect(try roundtrip(block) == block)
    }

    @Test("callout variants info / tip / warning all roundtrip")
    func calloutRoundtrip() throws {
        for variant in [ContentBlock.CalloutVariant.info, .tip, .warning] {
            let block = ContentBlock.callout(variant: variant, runs: [InlineRun(text: "hi")])
            #expect(try roundtrip(block) == block)
        }
    }

    @Test("image with and without caption roundtrip")
    func imageRoundtrip() throws {
        let withCaption = ContentBlock.image(asset: "fig.png", caption: "Figure 1")
        let withoutCaption = ContentBlock.image(asset: "fig.png", caption: nil)
        #expect(try roundtrip(withCaption) == withCaption)
        #expect(try roundtrip(withoutCaption) == withoutCaption)
    }

    @Test("decoded JSON matches the on-disk shape from the plan")
    func decodesAuthoritativeShape() throws {
        let json = """
        {
          "type": "paragraph",
          "runs": [
            { "text": "An agent " },
            { "text": "decides", "marks": ["italic"] },
            { "text": " what to do." }
          ]
        }
        """.data(using: .utf8)!
        let block = try JSONDecoder().decode(ContentBlock.self, from: json)
        guard case .paragraph(let runs) = block else {
            Issue.record("Expected paragraph case")
            return
        }
        #expect(runs.count == 3)
        #expect(runs[1].marks == [.italic])
    }

    @Test("link inline run keeps href across roundtrip")
    func linkHrefRoundtrip() throws {
        let run = InlineRun(text: "click", marks: [.link], href: "https://x.example")
        let block = ContentBlock.paragraph(runs: [run])
        let restored = try roundtrip(block)
        guard case .paragraph(let runs) = restored else {
            Issue.record("Expected paragraph")
            return
        }
        #expect(runs.first?.href == "https://x.example")
        #expect(runs.first?.marks == [.link])
    }
}

@Suite("Book content types — Codable roundtrip")
struct BookContentTypesCodableTests {

    @Test("BookCard roundtrip preserves explanation and feynman blocks")
    func bookCardRoundtrip() throws {
        let card = BookCard(
            id: "ch01-c001",
            order: 1,
            title: "Tool-Use Loop",
            teaser: "think → act → observe",
            explanation: [.paragraph(runs: [InlineRun(text: "explain")])],
            feynman: [.paragraph(runs: [InlineRun(text: "analogy")])]
        )
        let data = try JSONEncoder().encode(card)
        let restored = try JSONDecoder().decode(BookCard.self, from: data)
        #expect(restored == card)
    }

    @Test("ChapterSummary roundtrip preserves shards order")
    func chapterSummaryRoundtrip() throws {
        let chapter = ChapterSummary(
            id: "ch01",
            order: 1,
            title: "Foundations",
            summary: "intro",
            icon: "book",
            cardCount: 12,
            cardIds: ["c1", "c2", "c3"],
            shards: ["chapters/ch01.json", "chapters/ch01-part2.json"]
        )
        let data = try JSONEncoder().encode(chapter)
        let restored = try JSONDecoder().decode(ChapterSummary.self, from: data)
        #expect(restored == chapter)
    }

    @Test("BookManifest roundtrip with optional author = nil")
    func manifestRoundtrip() throws {
        let manifest = BookManifest(
            id: "book-id",
            version: 1,
            title: "Title",
            author: nil,
            summary: "summary",
            categories: [.codeCraft],
            chapters: []
        )
        let data = try JSONEncoder().encode(manifest)
        let restored = try JSONDecoder().decode(BookManifest.self, from: data)
        #expect(restored == manifest)
    }

    @Test("BooksCatalog roundtrip with one freeForAll entry")
    func catalogRoundtrip() throws {
        let catalog = BooksCatalog(
            version: 1,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            books: [
                BookSummary(
                    id: "free-book",
                    title: "Free",
                    author: "Author",
                    summary: "summary",
                    coverIcon: "book",
                    accentHex: "#7B61FF",
                    tags: ["agents"],
                    categories: [.aiML],
                    chapterCount: 1,
                    cardCount: 5,
                    manifestVersion: 1,
                    manifestPath: "books/free-book/manifest.json",
                    freeForAll: true,
                    sizeBytes: 1024
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(catalog)
        let restored = try decoder.decode(BooksCatalog.self, from: data)
        #expect(restored == catalog)
    }
}
