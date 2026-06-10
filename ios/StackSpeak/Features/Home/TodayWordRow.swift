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

            Spacer()

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
