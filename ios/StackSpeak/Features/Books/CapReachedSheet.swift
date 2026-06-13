import SwiftUI

/// Sheet shown when the user has hit their self-set book daily cap.
/// Offers two actions: read one more anyway, or dismiss.
struct CapReachedSheet: View {
    @Environment(\.theme) private var theme
    let onReadAnyway: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            Image(systemName: "leaf.fill")
                .font(.system(.largeTitle))
                .foregroundColor(theme.colors.good)
                .padding(.top, theme.spacing.xl)
            Text("books.cap.title")
                .font(TypographyTokens.title2)
                .foregroundColor(theme.colors.ink)
            Text("books.cap.message")
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.lg)
            Spacer()
            VStack(spacing: theme.spacing.sm) {
                PrimaryCTAButton("books.cap.readAnyway", action: onReadAnyway)
                Button("common.cancel", action: onDismiss)
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.inkMuted)
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .background(theme.colors.bg)
    }
}

#Preview("Cap Reached Sheet — Light") {
    CapReachedSheet(onReadAnyway: {}, onDismiss: {})
        .withTheme(ThemeManager())
}

#Preview("Cap Reached Sheet — Dark") {
    CapReachedSheet(onReadAnyway: {}, onDismiss: {})
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
