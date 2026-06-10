import Foundation

/// Inline marks applied to a `InlineRun`. Order matters for rendering composability
/// (bold before italic etc.) but is fixed at decode time.
enum InlineMark: String, Codable, Sendable {
    case bold
    case italic
    case code
    case link
}

/// One slice of inline text inside a block. Marks compose; `href` is only meaningful
/// when `marks` contains `.link`.
struct InlineRun: Codable, Sendable, Hashable {
    let text: String
    let marks: [InlineMark]?
    let href: String?

    init(text: String, marks: [InlineMark]? = nil, href: String? = nil) {
        self.text = text
        self.marks = marks
        self.href = href
    }
}
