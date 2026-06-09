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

/// One labelled column of a `comparison` block — a heading plus inline runs.
struct ComparisonColumn: Codable, Sendable, Hashable {
    let label: String
    let runs: [InlineRun]

    init(label: String, runs: [InlineRun]) {
        self.label = label
        self.runs = runs
    }
}

/// Decode-only helper for legacy `comparison` blocks shaped as
/// `{items:[{label|name, description}]}`. Flattened into a bulleted list item.
private struct ComparisonItem: Decodable {
    let label: String?
    let name: String?
    let description: String
    var asRuns: [InlineRun] {
        [InlineRun(text: label ?? name ?? "", marks: [.bold]),
         InlineRun(text: " — " + description)]
    }
}

/// Decode-only helper for legacy `comparison` blocks shaped as
/// `{rows:[{label, left, right}]}`. Flattened into a bulleted list item.
private struct ComparisonRow: Decodable {
    let label: String
    let left: String
    let right: String
    var asRuns: [InlineRun] {
        [InlineRun(text: label, marks: [.bold]),
         InlineRun(text: " — " + left + "  ·  " + right)]
    }
}

/// Structured content blocks used by book cards. The on-disk JSON is a tagged
/// union with a `"type"` discriminator — see plan `pro-and-books-plan.md`.
///
/// Block vocabulary: paragraph, heading, list, code, callout, image, table,
/// comparison. Adding new types is cheap; deprecating existing ones across an
/// authored corpus is expensive — resist scope creep.
enum ContentBlock: Codable, Sendable, Hashable {
    case paragraph(runs: [InlineRun])
    case heading(level: Int, text: String)
    case list(style: ListStyle, items: [[InlineRun]])
    case code(language: String, code: String)
    case callout(variant: CalloutVariant, runs: [InlineRun])
    case image(asset: String, caption: String?)
    case table(headers: [String], rows: [[String]])
    case comparison(left: ComparisonColumn, right: ComparisonColumn)

    enum ListStyle: String, Codable, Sendable {
        case bulleted
        case numbered
        /// Legacy synonym for `numbered`; renders identically.
        case ordered
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
        case lang      // legacy alias for `language`
        case code
        case content   // legacy alias for `code`
        case variant
        case asset
        case caption
        case headers
        case rows
        case left
        case right
    }

    private enum BlockType: String, Codable {
        case paragraph
        case heading
        case list
        case code
        case callout
        case image
        case table
        case comparison
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
            // Legacy content is inconsistent: language is `language` or `lang`;
            // the source is `code`, `text`, or `content`. Be lenient on all.
            let language = try c.decodeIfPresent(String.self, forKey: .language)
                ?? c.decodeIfPresent(String.self, forKey: .lang) ?? ""
            let code = try c.decodeIfPresent(String.self, forKey: .code)
                ?? c.decodeIfPresent(String.self, forKey: .text)
                ?? c.decodeIfPresent(String.self, forKey: .content) ?? ""
            self = .code(language: language, code: code)
        case .callout:
            let variant = try c.decode(CalloutVariant.self, forKey: .variant)
            let runs = try c.decode([InlineRun].self, forKey: .runs)
            self = .callout(variant: variant, runs: runs)
        case .image:
            let asset = try c.decode(String.self, forKey: .asset)
            let caption = try c.decodeIfPresent(String.self, forKey: .caption)
            self = .image(asset: asset, caption: caption)
        case .table:
            let headers = try c.decode([String].self, forKey: .headers)
            let rows = try c.decode([[String]].self, forKey: .rows)
            self = .table(headers: headers, rows: rows)
        case .comparison:
            // "comparison" was an un-schema'd grab-bag in legacy content with six
            // shapes. Normalize each onto a coherent block at decode time:
            //   {left,right}                       -> two-column comparison
            //   {headers,rows}                     -> table
            //   {rows:[{label,left,right}]}        -> bulleted list (label — a · b)
            //   {items:[{label|name,description}]} -> bulleted list (label — desc)
            if c.contains(.left), c.contains(.right) {
                let left = try c.decode(ComparisonColumn.self, forKey: .left)
                let right = try c.decode(ComparisonColumn.self, forKey: .right)
                self = .comparison(left: left, right: right)
            } else if c.contains(.headers) {
                let headers = try c.decode([String].self, forKey: .headers)
                let rows = try c.decode([[String]].self, forKey: .rows)
                self = .table(headers: headers, rows: rows)
            } else if c.contains(.items) {
                let items = try c.decode([ComparisonItem].self, forKey: .items)
                self = .list(style: .bulleted, items: items.map(\.asRuns))
            } else if c.contains(.rows) {
                let rows = try c.decode([ComparisonRow].self, forKey: .rows)
                self = .list(style: .bulleted, items: rows.map(\.asRuns))
            } else {
                throw DecodingError.dataCorruptedError(
                    forKey: .type, in: c,
                    debugDescription: "Unrecognized comparison block shape")
            }
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
        case .table(let headers, let rows):
            try c.encode(BlockType.table, forKey: .type)
            try c.encode(headers, forKey: .headers)
            try c.encode(rows, forKey: .rows)
        case .comparison(let left, let right):
            try c.encode(BlockType.comparison, forKey: .type)
            try c.encode(left, forKey: .left)
            try c.encode(right, forKey: .right)
        }
    }
}
