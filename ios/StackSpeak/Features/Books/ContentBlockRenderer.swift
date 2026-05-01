import SwiftUI

/// Renders a `ContentBlock` to a SwiftUI view tree. Pure presentation —
/// formatting decisions live entirely in tokens (`TypographyTokens`,
/// `theme.colors`, `theme.spacing`).
///
/// Block vocabulary v1: paragraph, heading, list, code, callout, image.
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
        let font: Font = level == 2 ? TypographyTokens.title2 : TypographyTokens.title3
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
        case .numbered: return "\(index + 1)."
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
            for mark in run.marks ?? [] {
                switch mark {
                case .bold:
                    part.font = TypographyTokens.body.weight(.semibold)
                case .italic:
                    part.font = TypographyTokens.body.italic()
                case .code:
                    part.font = TypographyTokens.code
                case .link:
                    if let href = run.href, let url = URL(string: href) {
                        part.link = url
                    }
                }
            }
            result.append(part)
        }
        return result
    }
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
