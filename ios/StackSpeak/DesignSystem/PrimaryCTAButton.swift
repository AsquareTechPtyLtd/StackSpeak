import SwiftUI

/// The single primary action button used across the app. Replaces the
/// half-dozen one-off `Button { Text(...).foregroundColor(.accentText)... }`
/// implementations that had drifted out of sync.
struct PrimaryCTAButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    let title: Text
    let isLoading: Bool
    let action: () -> Void

    init(_ titleKey: LocalizedStringKey, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = Text(titleKey)
        self.isLoading = isLoading
        self.action = action
    }

    /// For titles composed at runtime (e.g. "Start 7-day free trial" with the
    /// day count from StoreKit). Pass already-localized text only.
    init(verbatim title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = Text(verbatim: title)
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(theme.colors.accentText)
                } else {
                    title
                        .font(TypographyTokens.headline)
                }
            }
            .foregroundColor(theme.colors.accentText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacing.lg)
            .background(isEnabled ? theme.colors.accent : theme.colors.inkFaint)
            .clipShape(.rect(cornerRadius: RadiusTokens.card))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isLoading)
        .accessibilityHint(isEnabled ? Text("") : Text("a11y.cta.disabled"))
    }
}
