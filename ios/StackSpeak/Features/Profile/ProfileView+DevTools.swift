import SwiftUI
import SwiftData

extension ProfileView {
    /// Temporary developer section for toggling Pro access without a real IAP flow.
    /// Remove when StoreKit subscription is wired up.
    func devSection(progress: UserProgress) -> some View {
        cardSurface {
            VStack(spacing: theme.spacing.sm) {
                HStack(spacing: theme.spacing.md) {
                    Image(systemName: "hammer.fill")
                        .font(.system(.subheadline))
                        .foregroundColor(theme.colors.warn)
                        .frame(width: 24)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("profile.dev.proToggle")
                            .font(TypographyTokens.body)
                            .foregroundColor(theme.colors.ink)
                        Text("profile.dev.proToggle.subtitle")
                            .font(TypographyTokens.caption)
                            .foregroundColor(theme.colors.inkMuted)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { progress.isProActive },
                        set: { on in
                            progress.isPro = on
                            progress.proExpiryDate = on
                                ? Calendar.current.date(byAdding: .year, value: 1, to: Date())
                                : nil
                            try? modelContext.save()
                        }
                    ))
                    .labelsHidden()
                }
            }
        }
    }
}
