import SwiftUI

/// Renders a `ContentBlock` to a SwiftUI view tree. Pure presentation —
/// formatting decisions live entirely in tokens (`TypographyTokens`,
/// `theme.colors`, `theme.spacing`).
///
/// Block vocabulary: paragraph, heading, list, code, callout, image, table, comparison.
/// Inline marks v1: bold, italic, code, link.
struct ContentBlockView: View {
    @Environment(\.theme) private var theme

    let block: ContentBlock
    /// Used to resolve `image` block asset paths against the owning book's `images/`.
    let bookId: String

    var body: some View {
        switch block {
        case .paragraph(let runs):
            paragraph(runs)
        case .heading(let level, let text):
            heading(level: level, text: text)
        case .list(let style, let items):
            list(style: style, items: items)
        case .code(let language, let code):
            codeBlock(language: language, code: code)
        case .callout(let variant, let runs):
            callout(variant: variant, runs: runs)
        case .image(let asset, let caption):
            imageBlock(asset: asset, caption: caption)
        case .table(let headers, let rows):
            tableBlock(headers: headers, rows: rows)
        case .comparison(let left, let right):
            comparisonBlock(left: left, right: right)
        }
    }

    // MARK: - Block builders

    private func paragraph(_ runs: [InlineRun]) -> some View {
        InlineRunsText(runs: runs)
            .font(TypographyTokens.body)
            .foregroundColor(theme.colors.ink)
    }

    @ViewBuilder
    private func heading(level: Int, text: String) -> some View {
        // Level 1 (document title) must render larger than level 2; everything
        // deeper than level 2 steps down to title3.
        let font: Font = switch level {
        case 1: TypographyTokens.title1
        case 2: TypographyTokens.title2
        default: TypographyTokens.title3
        }
        Text(text)
            .font(font)
            .foregroundColor(theme.colors.ink)
            .padding(.top, theme.spacing.sm)
    }

    private func list(style: ContentBlock.ListStyle, items: [[InlineRun]]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: theme.spacing.sm) {
                    Text(bullet(for: style, index: index))
                        .font(TypographyTokens.body.monospacedDigit())
                        .foregroundColor(theme.colors.inkMuted)
                        .frame(minWidth: 22, alignment: .leading)
                    InlineRunsText(runs: item)
                        .font(TypographyTokens.body)
                        .foregroundColor(theme.colors.ink)
                }
            }
        }
    }

    private func bullet(for style: ContentBlock.ListStyle, index: Int) -> String {
        switch style {
        case .bulleted: return "•"
        case .numbered, .ordered: return "\(index + 1)."
        }
    }

    private func codeBlock(language: String, code: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            if !language.isEmpty {
                Text(language.uppercased())
                    .font(TypographyTokens.caption.weight(.semibold))
                    .foregroundColor(theme.colors.inkFaint)
            }
            Text(code)
                .font(TypographyTokens.code)
                .foregroundColor(theme.colors.codeInk)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(theme.spacing.md)
        .background(theme.colors.codeBg)
        .clipShape(.rect(cornerRadius: RadiusTokens.inline))
        .accessibilityLabel(language.isEmpty
                            ? Text(verbatim: code)
                            : Text(String(format: String(localized: "a11y.codeExample.format"), language)))
    }

    private func callout(variant: ContentBlock.CalloutVariant, runs: [InlineRun]) -> some View {
        let tint = calloutTint(variant)
        return HStack(alignment: .top, spacing: theme.spacing.sm) {
            Image(systemName: calloutIcon(variant))
                .foregroundColor(tint)
                .accessibilityHidden(true)
            InlineRunsText(runs: runs)
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.ink)
        }
        .padding(theme.spacing.md)
        .background(tint.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.inline)
                .stroke(tint.opacity(0.3), lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: RadiusTokens.inline))
    }

    private func calloutTint(_ variant: ContentBlock.CalloutVariant) -> Color {
        switch variant {
        case .info: return theme.colors.accent
        case .tip: return theme.colors.good
        case .warning: return theme.colors.warn
        }
    }

    private func calloutIcon(_ variant: ContentBlock.CalloutVariant) -> String {
        switch variant {
        case .info: return "info.circle.fill"
        case .tip: return "lightbulb.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    @ViewBuilder
    private func imageBlock(asset: String, caption: String?) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            // Phase 1+2 image bundling is not wired; render the asset path as a
            // friendly placeholder so authoring + preview still works.
            Image(systemName: "photo")
                .font(.system(.largeTitle))
                .foregroundColor(theme.colors.inkFaint)
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(theme.colors.surfaceAlt)
                .clipShape(.rect(cornerRadius: RadiusTokens.inline))
                .accessibilityLabel(caption ?? asset)
            if let caption {
                Text(caption)
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkMuted)
            }
        }
    }

    // MARK: - Table

    private func tableBlock(headers: [String], rows: [[String]]) -> some View {
        // Horizontal scroll keeps wide tables usable on iPhone without truncating cells.
        ScrollView(.horizontal, showsIndicators: true) {
            Grid(alignment: .topLeading, horizontalSpacing: theme.spacing.md, verticalSpacing: theme.spacing.sm) {
                GridRow {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                        Text(header)
                            .font(TypographyTokens.footnote.weight(.semibold))
                            .foregroundColor(theme.colors.ink)
                            .frame(minWidth: 80, alignment: .leading)
                    }
                }
                Divider().gridCellColumns(max(headers.count, 1))
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(TypographyTokens.footnote)
                                .foregroundColor(theme.colors.inkMuted)
                                .frame(minWidth: 80, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(theme.spacing.md)
        }
        .background(theme.colors.surfaceAlt)
        .clipShape(.rect(cornerRadius: RadiusTokens.inline))
    }

    // MARK: - Comparison

    private func comparisonBlock(left: ComparisonColumn, right: ComparisonColumn) -> some View {
        // Side-by-side when there's room; stacks on narrow widths / large type.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: theme.spacing.sm) {
                comparisonColumn(left)
                comparisonColumn(right)
            }
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                comparisonColumn(left)
                comparisonColumn(right)
            }
        }
    }

    private func comparisonColumn(_ column: ComparisonColumn) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(column.label)
                .font(TypographyTokens.footnote.weight(.semibold))
                .foregroundColor(theme.colors.ink)
            InlineRunsText(runs: column.runs)
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.md)
        .background(theme.colors.surfaceAlt)
        .clipShape(.rect(cornerRadius: RadiusTokens.inline))
    }
}

/// Resolves `[InlineRun]` into a single AttributedString for a `Text` view —
/// preserves bold/italic/code/link composition without `Text` concatenation
/// boilerplate. Returns plain text on parse failure.
private struct InlineRunsText: View {
    let runs: [InlineRun]

    var body: some View {
        Text(attributedString)
    }

    var attributedString: AttributedString {
        var result = AttributedString()
        for run in runs {
            var part = AttributedString(run.text)
            let marks = run.marks ?? []
            // Accumulate font modifiers across marks instead of reassigning per
            // mark — a [.bold, .italic] run previously kept only the last mark.
            // A code mark sets the base typeface; bold/italic layer on top.
            var font: Font? = marks.contains(.code) ? TypographyTokens.code : nil
            for mark in marks {
                switch mark {
                case .bold:
                    font = (font ?? TypographyTokens.body).weight(.semibold)
                case .italic:
                    font = (font ?? TypographyTokens.body).italic()
                case .code:
                    break  // handled as the base font above
                case .link:
                    if let href = run.href, let url = URL(string: href) {
                        part.link = url
                    }
                }
            }
            if let font {
                part.font = font
            }
            result.append(part)
        }
        return result
    }
}

// MARK: - Previews

private let previewBlocks: [ContentBlock] = [
    .heading(level: 1, text: "Actors in Swift"),
    .heading(level: 2, text: "Why Actors?"),
    .heading(level: 3, text: "Under the Hood"),
    .paragraph(runs: [
        InlineRun(text: "An "),
        InlineRun(text: "actor", marks: [.bold]),
        InlineRun(text: " is a reference type that "),
        InlineRun(text: "serialises", marks: [.italic]),
        InlineRun(text: " access to its mutable state. Calling "),
        InlineRun(text: "actor.doWork()", marks: [.code]),
        InlineRun(text: " from outside the actor is always an "),
        InlineRun(text: "async", marks: [.code, .italic]),
        InlineRun(text: " operation.")
    ]),
    .list(style: .bulleted, items: [
        [InlineRun(text: "Eliminates data races at compile time")],
        [InlineRun(text: "Replaces locks and serial queues")],
        [InlineRun(text: "Works with "), InlineRun(text: "async/await", marks: [.code])]
    ]),
    .code(language: "swift", code: "actor Counter {\n    var value = 0\n    func increment() { value += 1 }\n}"),
    .callout(variant: .info, runs: [InlineRun(text: "Actors are reference types — they live on the heap.")]),
    .callout(variant: .tip, runs: [InlineRun(text: "Prefer actors over classes when you need mutable shared state.")]),
    .callout(variant: .warning, runs: [InlineRun(text: "Crossing actor boundaries always involves a suspend point.")]),
    .table(
        headers: ["Concept", "Description"],
        rows: [
            ["Actor isolation", "Access only from within the actor by default"],
            ["nonisolated", "Opt out of isolation for pure computed properties"]
        ]
    ),
    .comparison(
        left: ComparisonColumn(label: "Actor", runs: [InlineRun(text: "Serialised access; safe by default")]),
        right: ComparisonColumn(label: "Class", runs: [InlineRun(text: "Concurrent access; manual locking required")])
    )
]

#Preview("Content Blocks — Light") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(previewBlocks.enumerated()), id: \.offset) { _, block in
                ContentBlockView(block: block, bookId: "preview-book")
            }
        }
        .padding()
    }
    .withTheme(ThemeManager())
}

#Preview("Content Blocks — Dark") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(previewBlocks.enumerated()), id: \.offset) { _, block in
                ContentBlockView(block: block, bookId: "preview-book")
            }
        }
        .padding()
    }
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}

extension ContentBlockView {
    /// Pure helper — extracts the `href` for the first link mark in a list of runs,
    /// if any. Used by tests + accessibility surfacing.
    static func firstLinkHref(in runs: [InlineRun]) -> String? {
        for run in runs {
            if let marks = run.marks, marks.contains(.link), let href = run.href {
                return href
            }
        }
        return nil
    }

    /// Pure helper — resolves an image asset path against `bookId`'s images dir.
    /// Used by tests; production rendering uses bundle lookup.
    static func resolveImagePath(asset: String, bookId: String) -> String {
        "books/\(bookId)/images/\(asset)"
    }
}
