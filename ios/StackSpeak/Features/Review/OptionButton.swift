import SwiftUI

/// One answer option in the assessment quiz. Idle until the card is submitted,
/// then colored by correctness.
struct OptionButton: View {
    @Environment(\.theme) private var theme

    enum State { case idle, correct, incorrect }

    let text: String
    let isSelected: Bool
    let state: State
    let onTap: () -> Void

    private var border: Color {
        switch state {
        case .correct:   return theme.colors.good
        case .incorrect: return theme.colors.bad
        case .idle:      return isSelected ? theme.colors.accent : theme.colors.line
        }
    }

    private var fill: Color {
        switch state {
        case .correct:   return theme.colors.good.opacity(0.10)
        case .incorrect: return theme.colors.bad.opacity(0.10)
        case .idle:      return isSelected ? theme.colors.accentBg : theme.colors.surface
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top) {
                Text(text)
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: theme.spacing.sm)
            }
            .selectableCardChrome(
                isSelected: state != .idle || isSelected,
                fill: fill,
                border: border,
                padding: EdgeInsets(top: theme.spacing.md, leading: theme.spacing.md,
                                    bottom: theme.spacing.md, trailing: theme.spacing.md)
            )
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
        .accessibilityLabel(text)
        .accessibilityValue({
            switch state {
            case .correct:   return String(localized: "a11y.option.correct")
            case .incorrect: return String(localized: "a11y.option.incorrect")
            case .idle:      return isSelected ? String(localized: "a11y.option.selected") : ""
            }
        }())
    }
}

// MARK: - Previews

#Preview("Option Button — Light") {
    VStack(spacing: 12) {
        OptionButton(text: "Producing the same result no matter how many times it's applied.",
                     isSelected: true, state: .idle, onTap: {})
        OptionButton(text: "A cache that survives restarts.", isSelected: false, state: .correct, onTap: {})
        OptionButton(text: "A queue that drops messages.", isSelected: true, state: .incorrect, onTap: {})
    }
    .padding()
    .withTheme(ThemeManager())
}

#Preview("Option Button — Dark") {
    VStack(spacing: 12) {
        OptionButton(text: "Producing the same result no matter how many times it's applied.",
                     isSelected: true, state: .idle, onTap: {})
        OptionButton(text: "A cache that survives restarts.", isSelected: false, state: .correct, onTap: {})
        OptionButton(text: "A queue that drops messages.", isSelected: true, state: .incorrect, onTap: {})
    }
    .padding()
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}
