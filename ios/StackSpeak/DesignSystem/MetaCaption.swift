import SwiftUI

/// The "L3 · Junior Band 1" caption that previously appeared inline in
/// FeynmanCardView, WordDetailView, and WordReportSheet with three slightly
/// different treatments. One source of truth.
struct MetaCaption: View {
    @Environment(\.theme) private var theme

    let level: Int
    let secondary: String?

    init(level: Int, secondary: String? = nil) {
        self.level = level
        self.secondary = secondary
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("L\(level)")
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
