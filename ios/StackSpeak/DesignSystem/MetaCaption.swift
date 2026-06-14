import SwiftUI

/// The "Intermediate · noun" caption shown on word surfaces. A leading badge
/// (e.g. the content tier name) plus an optional secondary tag. One source of
/// truth for the treatment that previously appeared inline in several views.
struct MetaCaption: View {
    @Environment(\.theme) private var theme

    let badge: String
    let secondary: String?

    init(_ badge: String, secondary: String? = nil) {
        self.badge = badge
        self.secondary = secondary
    }

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            Text(badge)
                .font(TypographyTokens.mono)
                .foregroundColor(theme.colors.inkFaint)
            if let secondary {
                Text("·").foregroundColor(theme.colors.inkFaint)
                Text(secondary)
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkFaint)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("MetaCaption — Light") {
    VStack(alignment: .leading, spacing: 12) {
        MetaCaption("Intermediate")
        MetaCaption("Advanced", secondary: "noun")
        MetaCaption("Basic", secondary: "verb")
    }
    .padding()
    .withTheme(ThemeManager())
}

#Preview("MetaCaption — Dark") {
    VStack(alignment: .leading, spacing: 12) {
        MetaCaption("Intermediate")
        MetaCaption("Advanced", secondary: "noun")
        MetaCaption("Basic", secondary: "verb")
    }
    .padding()
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}
