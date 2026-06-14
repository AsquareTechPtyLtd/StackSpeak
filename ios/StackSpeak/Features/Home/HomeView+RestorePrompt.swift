import SwiftUI

// Fresh-install / reinstall restore nudge. Split out per the
// <TypeName>+<Concern>.swift convention; all stored properties live in
// HomeView.swift.
extension HomeView {
    /// Show only when there's nothing to lose locally (no practiced words),
    /// no account is linked yet, and the user hasn't dismissed it. A returning
    /// member sees the path back to their progress; a brand-new user ignores
    /// it and it disappears after the first practiced word.
    func shouldShowRestorePrompt(_ progress: UserProgress) -> Bool {
        !restorePromptDismissed
            && !accountLinked
            && progress.wordsPracticedIds.isEmpty
    }

    var restorePrompt: some View {
        HStack(spacing: theme.spacing.md) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                HStack(spacing: theme.spacing.xs) {
                    Image(systemName: "icloud.and.arrow.down.fill")
                        .foregroundColor(theme.colors.accent)
                        .accessibilityHidden(true)
                    Text("home.restore.title")
                        .font(TypographyTokens.headline)
                        .foregroundColor(theme.colors.ink)
                }
                Text("home.restore.message")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
            }
            Spacer()
            Button { tabRouterSelectProfile() } label: {
                Text("home.restore.signIn")
                    .font(TypographyTokens.callout.weight(.semibold))
                    .foregroundColor(theme.colors.accent)
            }
            Button { restorePromptDismissed = true } label: {
                Image(systemName: "xmark")
                    .font(.system(.caption))
                    .foregroundColor(theme.colors.inkFaint)
            }
            .accessibilityLabel(Text("common.close"))
        }
        .padding(theme.spacing.cardPadding)
        .background(theme.colors.accentBg)
        .clipShape(.rect(cornerRadius: RadiusTokens.card))
    }

    /// Routes to the Profile tab, where sign-in / restore lives. No-ops in
    /// contexts without a router (previews).
    private func tabRouterSelectProfile() {
        tabRouter?.selection = .profile
    }
}
