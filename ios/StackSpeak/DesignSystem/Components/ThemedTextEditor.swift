import SwiftUI

/// Chromed `TextEditor` with the ZStack-overlay placeholder (TextEditor has no
/// native placeholder) and a keyboard Done toolbar. Used by the Feynman
/// explain stage and the word-report notes field — the placeholder alignment
/// arithmetic lives here once instead of drifting per call site.
struct ThemedTextEditor: View {
    /// One height policy per editor — the enum makes "grows" and "fixed"
    /// mutually exclusive by construction instead of by comment.
    enum Height {
        /// Editor grows with content from this minimum.
        case grows(min: CGFloat)
        /// Fixed editor height.
        case fixed(CGFloat)
    }

    @Environment(\.theme) private var theme

    let placeholder: LocalizedStringKey
    @Binding var text: String
    let focus: FocusState<Bool>.Binding
    let height: Height
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

    private var minHeight: CGFloat? {
        if case .grows(let min) = height { return min }
        return nil
    }

    private var fixedHeight: CGFloat? {
        if case .fixed(let value) = height { return value }
        return nil
    }

    @ViewBuilder
    private var editor: some View {
        let base = TextEditor(text: $text)
            .font(TypographyTokens.body)
            .foregroundColor(theme.colors.ink)
            .scrollContentBackground(.hidden)
            .frame(minHeight: minHeight)
            .frame(height: fixedHeight)
            // Free-text fields — suppress content-type inference so QuickType
            // never offers stored personal data as suggestions here.
            .textContentType(.none)
            .padding(theme.spacing.sm)
            .background(theme.colors.surfaceAlt)
            .clipShape(.rect(cornerRadius: RadiusTokens.inline))
            // A visible border so the field reads as an input — and an accent
            // ring while focused so it stays clearly delineated against the card
            // once the keyboard is up.
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.inline)
                    .strokeBorder(
                        focus.wrappedValue ? theme.colors.accent : theme.colors.lineStrong,
                        lineWidth: focus.wrappedValue ? 2 : 1
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: focus.wrappedValue)
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

// MARK: - Previews

/// Wrapper so previews can supply the required @FocusState binding.
private struct ThemedTextEditorPreview: View {
    @State private var emptyText = ""
    @State private var filledText = "An operation is idempotent if applying it twice equals applying it once."
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 16) {
            ThemedTextEditor(
                placeholder: "feynman.explain.placeholder",
                text: $emptyText,
                focus: $focused,
                height: .grows(min: 120)
            )
            ThemedTextEditor(
                placeholder: "report.notes.placeholder",
                text: $filledText,
                focus: $focused,
                height: .fixed(100)
            )
        }
        .padding()
    }
}

#Preview("Themed Text Editor — Light") {
    ThemedTextEditorPreview()
        .withTheme(ThemeManager())
}

#Preview("Themed Text Editor — Dark") {
    ThemedTextEditorPreview()
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
