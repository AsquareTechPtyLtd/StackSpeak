import Testing
import Foundation
@testable import StackSpeak

@Suite("ContentBlockView — pure helpers")
@MainActor
struct ContentBlockRendererHelperTests {

    @Test("firstLinkHref returns the first link mark's href")
    func firstLinkHrefHappy() {
        let runs: [InlineRun] = [
            InlineRun(text: "see "),
            InlineRun(text: "docs", marks: [.link], href: "https://example.com"),
            InlineRun(text: " then "),
            InlineRun(text: "spec", marks: [.link], href: "https://example.com/spec")
        ]
        #expect(ContentBlockView.firstLinkHref(in: runs) == "https://example.com")
    }

    @Test("firstLinkHref returns nil when no link marks present")
    func firstLinkHrefNone() {
        let runs: [InlineRun] = [InlineRun(text: "plain"), InlineRun(text: "bold", marks: [.bold])]
        #expect(ContentBlockView.firstLinkHref(in: runs) == nil)
    }

    @Test("resolveImagePath joins bookId + asset under books/<id>/images/")
    func imagePathResolution() {
        #expect(ContentBlockView.resolveImagePath(asset: "fig.png", bookId: "ai-agents")
                == "books/ai-agents/images/fig.png")
    }
}
