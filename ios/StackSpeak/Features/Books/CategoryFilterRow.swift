import SwiftUI

/// Horizontally scrolling chip row for the Books tab. Shows an "All" chip
/// followed by the 7 locked `BookCategory` chips in taxonomy order. Multi-select
/// with OR semantics — selecting two categories shows books matching either.
///
/// Tapping "All" clears any selection. Tapping a category toggles its membership
/// in the selection set; the parent view owns the binding.
struct CategoryFilterRow: View {
    @Environment(\.theme) private var theme

    @Binding var selectedCategories: Set<BookCategory>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.sm) {
                CategoryFilterChip(
                    category: nil,
                    label: "filter.all",
                    isSelected: selectedCategories.isEmpty
                ) {
                    selectedCategories.removeAll()
                }
                ForEach(BookCategory.allCases) { category in
                    CategoryFilterChip(
                        category: category,
                        label: category.displayName,
                        isSelected: selectedCategories.contains(category)
                    ) {
                        toggle(category)
                    }
                }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.vertical, theme.spacing.sm)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("filter.row.a11yLabel")
    }

    private func toggle(_ category: BookCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
}

#Preview("Filter row — All selected (light)") {
    StatefulPreviewWrapper(Set<BookCategory>()) { binding in
        CategoryFilterRow(selectedCategories: binding)
            .withTheme(ThemeManager())
    }
}

#Preview("Filter row — multi-select (dark)") {
    StatefulPreviewWrapper(Set<BookCategory>([.aiML, .testing])) { binding in
        CategoryFilterRow(selectedCategories: binding)
            .withTheme(ThemeManager())
            .preferredColorScheme(.dark)
    }
}

/// Tiny helper for SwiftUI previews that need mutable state.
private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initial)
        self.content = content
    }

    var body: some View { content($value) }
}
