import SwiftUI

struct TodayWordRow: View {
    @Environment(\.theme) private var theme

    let number: Int
    let word: Word
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            ZStack {
                Circle()
                    .fill(isCompleted ? theme.colors.accentBg : theme.colors.surfaceAlt)
                    .frame(width: 32, height: 32)
                Text("\(number)")
                    .font(TypographyTokens.mono)
                    .foregroundColor(isCompleted ? theme.colors.accent : theme.colors.inkMuted)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(word.word)
                    .font(isCompleted
                          ? TypographyTokens.body.weight(.regular)
                          : TypographyTokens.headline)
                    .foregroundColor(isCompleted ? theme.colors.inkMuted : theme.colors.ink)
                    .strikethrough(isCompleted, color: theme.colors.inkFaint)
                Text(word.pronunciation)
                    .font(TypographyTokens.mono)
                    .foregroundColor(theme.colors.inkFaint)
            }

            Spacer(minLength: theme.spacing.sm)

            TopicChip(label: word.topicLabel)

            if isCompleted {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(.headline))
                    .foregroundColor(theme.colors.good)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundColor(theme.colors.inkFaint)
                    .accessibilityHidden(true)
            }
        }
        .padding(theme.spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardChrome()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(word.word). \(isCompleted ? String(localized: "a11y.completed") : "")")
    }
}

// MARK: - Previews

private func previewWord() -> Word {
    Word(
        id: UUID(),
        word: "idempotent",
        pronunciation: "/ˌaɪ.dəmˈpoʊ.tənt/",
        partOfSpeech: "adjective",
        shortDefinition: "Produces the same result no matter how many times it's applied.",
        simpleDefinition: "Doing it once or a hundred times gives the same outcome.",
        longDefinition: "An operation is idempotent if applying it multiple times has the same effect as applying it once.",
        techContext: "REST APIs mark GET, PUT, and DELETE as idempotent.",
        exampleSentence: "A DELETE request is idempotent — deleting a resource twice is the same as deleting it once.",
        etymology: "From Latin idem (same) + potent (powerful).",
        connector: "Think of a light switch that only turns off.",
        codeExampleLanguage: "swift",
        codeExampleCode: "",
        stack: "basic-web",
        unlockLevel: 1,
        tags: ["api", "http"]
    )
}

#Preview("TodayWordRow — Light") {
    VStack(spacing: 8) {
        TodayWordRow(number: 1, word: previewWord(), isCompleted: false)
        TodayWordRow(number: 2, word: previewWord(), isCompleted: true)
    }
    .padding()
    .withTheme(ThemeManager())
}

#Preview("TodayWordRow — Dark") {
    VStack(spacing: 8) {
        TodayWordRow(number: 1, word: previewWord(), isCompleted: false)
        TodayWordRow(number: 2, word: previewWord(), isCompleted: true)
    }
    .padding()
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}
