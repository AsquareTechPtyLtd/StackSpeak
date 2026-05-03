import SwiftUI

/// A single chip in the Books-tab category filter row. Renders an icon + label;
/// optionally an "All" variant that has no icon. Selected state tints the chip
/// with the category's accent or the theme accent (for All).
///
/// The chip is purely presentational — selection state is owned by the parent
/// row's view model.
struct CategoryFilterChip: View {
    @Environment(\.theme) private var theme

    /// `nil` indicates the "All" chip — no icon, theme-accent fill when selected.
    let category: BookCategory?
    let label: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    private var accent: Color {
        guard let category else { return theme.colors.accent }
        return Color(hex: category.accentHex)
    }

    private var bg: Color {
        isSelected ? accent.opacity(0.16) : theme.colors.surface
    }

    private var border: Color {
        isSelected ? accent : theme.colors.line
    }

    private var foreground: Color {
        isSelected ? accent : theme.colors.inkMuted
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.xs) {
                if let category {
                    Image(systemName: category.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(label)
                    .font(TypographyTokens.footnote.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundColor(foreground)
            .padding(.horizontal, theme.spacing.md)
            .padding(.vertical, theme.spacing.sm)
            .background(bg)
            .clipShape(.rect(cornerRadius: RadiusTokens.pill))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.pill)
                    .stroke(border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(MotionTokens.snappy, value: isSelected)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview("Category chip — light") {
    HStack {
        CategoryFilterChip(category: nil, label: "filter.all", isSelected: true, action: {})
        CategoryFilterChip(category: .aiML, label: "category.ai_ml", isSelected: false, action: {})
        CategoryFilterChip(category: .testing, label: "category.testing", isSelected: true, action: {})
    }
    .padding()
    .background(Color(.systemBackground))
    .withTheme(ThemeManager())
}

#Preview("Category chip — dark") {
    HStack {
        CategoryFilterChip(category: nil, label: "filter.all", isSelected: true, action: {})
        CategoryFilterChip(category: .aiML, label: "category.ai_ml", isSelected: false, action: {})
        CategoryFilterChip(category: .testing, label: "category.testing", isSelected: true, action: {})
    }
    .padding()
    .background(Color(.systemBackground))
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}
