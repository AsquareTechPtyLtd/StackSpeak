import SwiftUI

/// CC3 — single empty-state primitive used by Library, Review (Assessment +
/// Flashcards), and Today (all-mastered). Each can include an optional
/// primary action so the screen is a launchpad rather than a dead end.
struct EmptyStateView: View {
    @Environment(\.theme) private var theme

    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?
    let secondaryActionTitle: LocalizedStringKey?
    let secondaryAction: (() -> Void)?

    init(
        icon: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil,
        secondaryActionTitle: LocalizedStringKey? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
    }

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            Spacer()
            Image(systemName: icon)
                .scaledIcon(size: IconSizeTokens.large, weight: .light)
                .foregroundColor(theme.colors.inkFaint)
                .accessibilityHidden(true)
            VStack(spacing: theme.spacing.xs) {
                Text(title)
                    .font(TypographyTokens.title2)
                    .foregroundColor(theme.colors.ink)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacing.xl)
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(TypographyTokens.headline)
                        .foregroundColor(theme.colors.accent)
                }
                .padding(.top, theme.spacing.xs)
            }
            if let secondaryActionTitle, let secondaryAction {
                Button(action: secondaryAction) {
                    Text(secondaryActionTitle)
                        .font(TypographyTokens.subheadline)
                        .foregroundColor(theme.colors.inkMuted)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("EmptyStateView — Light") {
    VStack {
        EmptyStateView(
            icon: "books.vertical",
            title: "No books yet",
            message: "Books will appear here as the catalog grows."
        )
        EmptyStateView(
            icon: "rectangle.stack",
            title: "No flashcards due today",
            message: "Words you practice appear here the next day.",
            actionTitle: "Browse the Library",
            action: {}
        )
    }
    .withTheme(ThemeManager())
}

#Preview("EmptyStateView — Dark") {
    EmptyStateView(
        icon: "rectangle.stack",
        title: "No flashcards due today",
        message: "Words you practice appear here the next day.",
        actionTitle: "Browse the Library",
        action: {},
        secondaryActionTitle: "Manage stacks",
        secondaryAction: {}
    )
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}
