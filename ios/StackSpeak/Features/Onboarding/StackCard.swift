import SwiftUI

/// Shared stack-row component used by Stack Selection (onboarding), Stack
/// Management (settings), and the Level-Up sheet's optional picker.
struct StackCard: View {
    @Environment(\.theme) private var theme

    let stack: WordStack
    let isSelected: Bool
    let isLocked: Bool
    let onToggle: () -> Void

    init(stack: WordStack, isSelected: Bool,
         isLocked: Bool = false, onToggle: @escaping () -> Void) {
        self.stack = stack
        self.isSelected = isSelected
        self.isLocked = isLocked
        self.onToggle = onToggle
    }

    var body: some View {
        Group {
            if isLocked {
                cardContent
                    .accessibilityLabel(stack.displayName)
                    .accessibilityValue(isSelected ? "selected" : "not selected")
                    .accessibilityHint(isLocked ? String(localized: "stacks.locked.a11yHint") : "")
            } else {
                Button(action: onToggle) { cardContent }
                    .buttonStyle(.plain)
                    .accessibilityLabel(stack.displayName)
                    .accessibilityValue(isSelected ? "selected" : "not selected")
                    .accessibilityAddTraits(.isButton)
            }
        }
    }

    private enum CardState { case locked, active, idle }

    private var cardState: CardState {
        if isLocked { return .locked }
        return isSelected ? .active : .idle
    }

    private var cardContent: some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: stack.icon)
                .font(.system(.title2))
                .foregroundColor(iconForeground)
                .frame(width: 36, height: 36)
                .background(iconBackground)
                .clipShape(.rect(cornerRadius: RadiusTokens.inline))

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(stack.displayName)
                    .font(TypographyTokens.headline)
                    .foregroundColor(isLocked ? theme.colors.inkMuted : theme.colors.ink)

                Text(stack.description)
                    .font(TypographyTokens.footnote)
                    .foregroundColor(theme.colors.inkMuted)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: radioIcon)
                .font(.system(.title2))
                .foregroundColor(radioColor)
        }
        .selectableCardChrome(isSelected: cardState == .active)
    }

    /// Locked cards (core stacks for free users) are always included in the
    /// user's selection, so the radio shows a checkmark — grayed out to signal
    /// it can't be toggled.
    private var radioIcon: String {
        switch cardState {
        case .locked: return isSelected ? "checkmark.circle.fill" : "circle"
        case .active: return "checkmark.circle.fill"
        case .idle:   return "circle"
        }
    }

    private var radioColor: Color {
        cardState == .active ? theme.colors.accent : theme.colors.inkFaint
    }

    private var iconForeground: Color {
        switch cardState {
        case .locked: return theme.colors.inkFaint
        case .active: return theme.colors.accent
        case .idle:   return theme.colors.inkMuted
        }
    }

    private var iconBackground: Color {
        cardState == .active ? theme.colors.accentBg : theme.colors.surfaceAlt
    }
}

#Preview("StackCard — Light") {
    VStack(spacing: 8) {
        StackCard(stack: WordStack(rawValue: "basic-api-design"), isSelected: true, onToggle: {})
        StackCard(stack: WordStack(rawValue: "basic-testing"), isSelected: false, onToggle: {})
        StackCard(stack: WordStack(rawValue: "basic-system-design"), isSelected: true, isLocked: true, onToggle: {})
    }
    .padding()
    .withTheme(ThemeManager())
}

#Preview("StackCard — Dark") {
    VStack(spacing: 8) {
        StackCard(stack: WordStack(rawValue: "basic-api-design"), isSelected: true, onToggle: {})
        StackCard(stack: WordStack(rawValue: "basic-testing"), isSelected: false, onToggle: {})
        StackCard(stack: WordStack(rawValue: "basic-system-design"), isSelected: true, isLocked: true, onToggle: {})
    }
    .padding()
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}
