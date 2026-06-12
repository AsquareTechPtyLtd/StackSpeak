import SwiftUI

/// Chromed `TextEditor` with the ZStack-overlay placeholder (TextEditor has no
/// native placeholder) and a keyboard Done toolbar. Used by the Feynman
/// explain stage and the word-report notes field — the placeholder alignment
/// arithmetic lives here once instead of drifting per call site.
struct ThemedTextEditor: View {
    @Environment(\.theme) private var theme

    let placeholder: LocalizedStringKey
    @Binding var text: String
    let focus: FocusState<Bool>.Binding
    /// Editor grows from this height with content.
    var minHeight: CGFloat?
    /// Fixed editor height; mutually exclusive with `minHeight` in practice.
    var height: CGFloat?
    var accessibilityLabel: String?

    /// Nudges that align the overlay placeholder with TextEditor's internal
    /// text origin (which sits inset from the view's own frame).
    private static let placeholderXNudge: CGFloat = 5
    private static let placeholderYNudge: CGFloat = 8

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.inkFaint)
                    .padding(.horizontal, theme.spacing.sm + Self.placeholderXNudge)
                    .padding(.vertical, theme.spacing.sm + Self.placeholderYNudge)
                    .allowsHitTesting(false)
            }
            editor
        }
    }

    @ViewBuilder
    private var editor: some View {
        let base = TextEditor(text: $text)
            .font(TypographyTokens.body)
            .foregroundColor(theme.colors.ink)
            .scrollContentBackground(.hidden)
            .frame(minHeight: minHeight)
            .frame(height: height)
            .padding(theme.spacing.sm)
            .background(theme.colors.surfaceAlt)
            .clipShape(.rect(cornerRadius: RadiusTokens.inline))
            .focused(focus)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "common.done")) {
                        focus.wrappedValue = false
                    }
                    .foregroundColor(theme.colors.accent)
                }
            }
        if let accessibilityLabel {
            base.accessibilityLabel(accessibilityLabel)
        } else {
            base
        }
    }
}
