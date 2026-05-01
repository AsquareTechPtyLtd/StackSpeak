import SwiftUI

/// Sentence-case section label used inside cards (WordDetail sections,
/// Feynman done-stage subheadings, etc.). Lives in DesignSystem so callers
/// don't grow file-local copies that drift apart.
///
/// Replaces the prior UPPERCASE-tracked caption — that styling is now
/// reserved for code/metadata, not UI chrome.
struct SectionHeader: View {
    @Environment(\.theme) private var theme
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    init(title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(TypographyTokens.subheadline.weight(.medium))
            .foregroundColor(theme.colors.inkMuted)
    }
}
