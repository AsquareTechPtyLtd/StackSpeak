import SwiftUI

/// Resolves `[InlineRun]` into a single AttributedString for a `Text` view —
/// preserves bold/italic/code/link composition without `Text` concatenation
/// boilerplate. Returns plain text on parse failure.
///
/// - Parameter contextFont: the ambient font the caller applied via `.font()`.
///   Bold/italic runs use this as the base so they match the surrounding size
///   (e.g. `.callout` in a callout block, `.body` in a paragraph).
struct InlineRunsText: View {
    let runs: [InlineRun]
    var contextFont: Font = TypographyTokens.body

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
            // Bold/italic fall back to `contextFont` (not a hardcoded size) so
            // they honour whatever ambient font the call site applied.
            var font: Font? = marks.contains(.code) ? TypographyTokens.code : nil
            for mark in marks {
                switch mark {
                case .bold:
                    font = (font ?? contextFont).weight(.semibold)
                case .italic:
                    font = (font ?? contextFont).italic()
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
