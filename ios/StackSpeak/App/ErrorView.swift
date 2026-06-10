import SwiftUI

/// Full-screen failure surface for an unrecoverable launch error (e.g. the
/// SwiftData store failed to open). Offers a user-confirmed local reset when
/// `onReset` is provided.
struct ErrorView: View {
    @Environment(\.theme) private var theme
    let error: Error
    /// User-confirmed local-reset recovery. When provided, the screen offers a
    /// "Reset Local Data" action as a last resort for an unrecoverable store.
    var onReset: (() -> Void)?

    @State private var showResetConfirm = false

    var body: some View {
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            VStack(spacing: theme.spacing.xxl) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .scaledIcon(size: IconSizeTokens.large)
                    .foregroundColor(theme.colors.warn)

                Text("error.unableToStart.title")
                    .font(TypographyTokens.title1)
                    .foregroundColor(theme.colors.ink)

                Text("error.unableToStart.message")
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacing.xxxl)

                Text(error.localizedDescription)
                    .font(TypographyTokens.mono)
                    .foregroundColor(theme.colors.inkFaint)
                    .padding(theme.spacing.lg)
                    .background(theme.colors.surface)
                    .clipShape(.rect(cornerRadius: RadiusTokens.inline))
                    .padding(.horizontal, theme.spacing.xxxl)

                if onReset != nil {
                    Text("error.reset.info")
                        .font(TypographyTokens.callout)
                        .foregroundColor(theme.colors.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, theme.spacing.xxxl)

                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Text("error.reset.button")
                            .font(TypographyTokens.body.weight(.semibold))
                            .foregroundColor(theme.colors.bad)
                    }
                }
            }
        }
        .confirmationDialog(
            "error.reset.confirm.title",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("error.reset.button", role: .destructive) { onReset?() }
            Button("common.cancel", role: .cancel) { }
        } message: {
            Text("error.reset.confirm.message")
        }
    }
}

#Preview("Error — Light") {
    ErrorView(
        error: NSError(domain: "preview", code: 1,
                       userInfo: [NSLocalizedDescriptionKey: "The database could not be opened."]),
        onReset: {}
    )
    .withTheme(ThemeManager())
}

#Preview("Error — Dark") {
    ErrorView(
        error: NSError(domain: "preview", code: 1,
                       userInfo: [NSLocalizedDescriptionKey: "The database could not be opened."]),
        onReset: {}
    )
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}
