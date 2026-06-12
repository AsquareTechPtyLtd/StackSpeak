import SwiftUI

/// Circular close affordance for sheets that don't carry a NavigationStack
/// toolbar (e.g. the paywall). Overlay it top-trailing on the sheet root so
/// every modal shares one close-button treatment.
struct SheetCloseButton: View {
    @Environment(\.theme) private var theme

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(.subheadline, weight: .semibold)) // icon glyph
                .foregroundColor(theme.colors.inkMuted)
                .padding(theme.spacing.sm)
                .background(theme.colors.surfaceAlt, in: Circle())
        }
        .accessibilityLabel(Text("common.close"))
    }
}

#Preview("Sheet Close Button — Light") {
    SheetCloseButton(action: {})
        .padding()
        .withTheme(ThemeManager())
}

#Preview("Sheet Close Button — Dark") {
    SheetCloseButton(action: {})
        .padding()
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
