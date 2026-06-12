import SwiftUI

/// Small pill labeling a word's topic (e.g. "Web Security", "Git"), so terms
/// that recur across several stacks read unambiguously when browsing. Backed by
/// `Word.topicLabel`. Renders nothing for an empty label.
struct TopicChip: View {
    @Environment(\.theme) private var theme
    let label: String

    var body: some View {
        if !label.isEmpty {
            Text(label)
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.accent)
                .padding(.horizontal, theme.spacing.sm)
                .padding(.vertical, theme.spacing.xxs)
                .background(theme.colors.accent.opacity(0.12))
                .clipShape(.rect(cornerRadius: RadiusTokens.pill))
                .accessibilityLabel(Text(String(format: String(localized: "a11y.topicChip.format"), label)))
        }
    }
}

#Preview("TopicChip — Light") {
    HStack {
        TopicChip(label: "Web Security")
        TopicChip(label: "Git")
        TopicChip(label: "API")
    }
    .padding()
    .withTheme(ThemeManager())
}

#Preview("TopicChip — Dark") {
    HStack {
        TopicChip(label: "Distributed Data")
        TopicChip(label: "MLOps")
    }
    .padding()
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}
