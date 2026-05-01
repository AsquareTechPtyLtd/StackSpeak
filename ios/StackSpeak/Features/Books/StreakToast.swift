import SwiftUI

/// Subtle slide-in toast that announces a per-book reading streak.
/// Surfaces only when `currentStreakDays >= 2` and auto-dismisses after ~2s.
struct StreakToast: View {
    @Environment(\.theme) private var theme
    let days: Int

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Image(systemName: "flame.fill")
                .foregroundColor(theme.colors.streak)
                .accessibilityHidden(true)
            Text(String(format: String(localized: "books.streak.toast.format"), days))
                .font(TypographyTokens.subheadline.weight(.semibold))
                .foregroundColor(theme.colors.ink)
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.sm)
        .background(theme.colors.surface)
        .clipShape(.rect(cornerRadius: RadiusTokens.pill))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .accessibilityLabel(String(format: String(localized: "a11y.book.streak.toast.format"), days))
    }
}
