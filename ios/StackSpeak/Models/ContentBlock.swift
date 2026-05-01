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

/// Structured content blocks used by book cards. The on-disk JSON is a tagged
/// union with a `"type"` discriminator — see plan `pro-and-books-plan.md`.
///
/// Block vocabulary v1: paragraph, heading, list, code, callout, image.
/// Adding new types is cheap; deprecating existing ones across an authored corpus
/// is expensive — resist scope creep.
enum ContentBlock: Codable, Sendable, Hashable {
    case paragraph(runs: [InlineRun])
    case heading(level: Int, text: String)
    case list(style: ListStyle, items: [[InlineRun]])
    case code(language: String, code: String)
    case callout(variant: CalloutVariant, runs: [InlineRun])
    case image(asset: String, caption: String?)

    enum ListStyle: String, Codable, Sendable {
        case bulleted
        case numbered
    }

    enum CalloutVariant: String, Codable, Sendable {
        case info
        case tip
        case warning
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case runs
        case level
        case text
        case style
        case items
        case language
        case code
        case variant
        case asset
        case caption
    }

    private enum BlockType: String, Codable {
        case paragraph
        case heading
        case list
        case code
        case callout
        case image
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(BlockType.self, forKey: .type)
        switch type {
        case .paragraph:
            let runs = try c.decode([InlineRun].self, forKey: .runs)
            self = .paragraph(runs: runs)
        case .heading:
            let level = try c.decode(Int.self, forKey: .level)
            let text = try c.decode(String.self, forKey: .text)
            self = .heading(level: level, text: text)
        case .list:
            let style = try c.decode(ListStyle.self, forKey: .style)
            let items = try c.decode([[InlineRun]].self, forKey: .items)
            self = .list(style: style, items: items)
        case .code:
            let language = try c.decode(String.self, forKey: .language)
            let code = try c.decode(String.self, forKey: .code)
            self = .code(language: language, code: code)
        case .callout:
            let variant = try c.decode(CalloutVariant.self, forKey: .variant)
            let runs = try c.decode([InlineRun].self, forKey: .runs)
            self = .callout(variant: variant, runs: runs)
        case .image:
            let asset = try c.decode(String.self, forKey: .asset)
            let caption = try c.decodeIfPresent(String.self, forKey: .caption)
            self = .image(asset: asset, caption: caption)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .paragraph(let runs):
            try c.encode(BlockType.paragraph, forKey: .type)
            try c.encode(runs, forKey: .runs)
        case .heading(let level, let text):
            try c.encode(BlockType.heading, forKey: .type)
            try c.encode(level, forKey: .level)
            try c.encode(text, forKey: .text)
        case .list(let style, let items):
            try c.encode(BlockType.list, forKey: .type)
            try c.encode(style, forKey: .style)
            try c.encode(items, forKey: .items)
        case .code(let language, let code):
            try c.encode(BlockType.code, forKey: .type)
            try c.encode(language, forKey: .language)
            try c.encode(code, forKey: .code)
        case .callout(let variant, let runs):
            try c.encode(BlockType.callout, forKey: .type)
            try c.encode(variant, forKey: .variant)
            try c.encode(runs, forKey: .runs)
        case .image(let asset, let caption):
            try c.encode(BlockType.image, forKey: .type)
            try c.encode(asset, forKey: .asset)
            try c.encodeIfPresent(caption, forKey: .caption)
        }
    }
}
