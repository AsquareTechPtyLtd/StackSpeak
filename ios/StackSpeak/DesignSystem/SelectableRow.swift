import SwiftUI

/// A pick-one / pick-many row used by Theme settings, Stack management,
/// Assessment options, Word Report reasons, and Level-up unlocks. Single
/// selection signal: an `accentBg` fill plus a hairline-thick accent border —
/// no triple-stacked icon-plus-border-plus-fill chrome.
extension SelectableRow where Leading == EmptyView, Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool = false,
        role: Role = .picker,
        action: @escaping () -> Void = {}
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            isSelected: isSelected,
            role: role,
            action: action,
            leading: { EmptyView() },
            trailing: { EmptyView() }
        )
    }
}

extension SelectableRow where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool = false,
        role: Role = .picker,
        action: @escaping () -> Void = {},
        @ViewBuilder leading: () -> Leading
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            isSelected: isSelected,
            role: role,
            action: action,
            leading: leading,
            trailing: { EmptyView() }
        )
    }
}

struct SelectableRow<Leading: View, Trailing: View>: View {
    @Environment(\.theme) private var theme

    let title: String
    let subtitle: String?
    let isSelected: Bool
    let role: Role
    let action: () -> Void
    let leading: Leading
    let trailing: Trailing

    enum Role { case picker, multiselect, navigation }

    init(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool = false,
        role: Role = .picker,
        action: @escaping () -> Void = {},
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.role = role
        self.action = action
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.md) {
                leading

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(TypographyTokens.headline)
                        .foregroundColor(theme.colors.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(TypographyTokens.callout)
                            .foregroundColor(theme.colors.inkMuted)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                trailing

                roleIndicator
            }
            .padding(theme.spacing.cardPadding)
            .background(isSelected ? theme.colors.accentBg : theme.colors.surface)
            .clipShape(.rect(cornerRadius: RadiusTokens.card))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .stroke(isSelected ? theme.colors.accent : theme.colors.line,
                            lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var roleIndicator: some View {
        switch role {
        case .picker:
            Image(systemName: isSelected ? "checkmark" : "")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.colors.accent)
                .frame(width: 16)
        case .multiselect:
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(isSelected ? theme.colors.accent : theme.colors.inkFaint)
        case .navigation:
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(theme.colors.inkFaint)
        }
    }
}
