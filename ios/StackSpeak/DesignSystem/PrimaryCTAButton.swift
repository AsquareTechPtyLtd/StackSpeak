import SwiftUI

/// The single primary action button used across the app. Replaces the
/// half-dozen one-off `Button { Text(...).foregroundColor(.accentText)... }`
/// implementations that had drifted out of sync.
struct PrimaryCTAButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    let titleKey: LocalizedStringKey
    let isLoading: Bool
    let action: () -> Void

    init(_ titleKey: LocalizedStringKey, isLoading: Bool = false, action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(theme.colors.accentText)
                } else {
                    Text(titleKey)
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
