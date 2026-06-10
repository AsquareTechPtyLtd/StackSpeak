import SwiftUI
import SwiftData

/// Minimal locked-book gate shown when a non-pro user taps a pro book — from the
/// Books tab or from a word's "From the book" link. Replace with a full
/// subscription flow when in-app purchase is wired up.
struct BookLockedSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext

    let book: BookSummary

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: theme.spacing.lg) {
                Image(systemName: "lock.fill")
                    .scaledIcon(size: IconSizeTokens.large, weight: .semibold)
                    .foregroundColor(theme.colors.accent)

                VStack(spacing: theme.spacing.sm) {
                    Text("books.locked.title")
                        .font(TypographyTokens.title2)
                        .foregroundColor(theme.colors.ink)
                        .multilineTextAlignment(.center)

                    Text("books.locked.message")
                        .font(TypographyTokens.body)
                        .foregroundColor(theme.colors.inkMuted)
                        .multilineTextAlignment(.center)
                }

                PrimaryCTAButton("books.locked.cta") { dismiss() }

                devProToggle
            }
            .padding(theme.spacing.xl)

            Spacer()
        }
        .background(theme.colors.bg.ignoresSafeArea())
    }

    private var devProToggle: some View {
        HStack(spacing: theme.spacing.sm) {
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text("books.dev.proToggle")
                    .font(TypographyTokens.footnote.weight(.medium))
                    .foregroundColor(theme.colors.inkMuted)
                Text("books.dev.proToggle.subtitle")
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkFaint)
            }
            Spacer()
            #if DEBUG
            Toggle("", isOn: Binding(
                get: { userProgress?.isProActive ?? false },
                set: { on in
                    guard let progress = userProgress else { return }
                    // Capture pre-toggle state so a failed save restores BOTH
                    // fields — nil-ing the expiry on revert would strand a
                    // restored isPro=true with no expiry date.
                    let oldIsPro = progress.isPro
                    let oldExpiry = progress.proExpiryDate
                    progress.isPro = on
                    progress.proExpiryDate = on
                        ? Calendar.current.date(byAdding: .year, value: 1, to: Date())
                        : nil
                    do {
                        try modelContext.save()
                        if on { dismiss() }
                    } catch {
                        progress.isPro = oldIsPro
                        progress.proExpiryDate = oldExpiry
                    }
                }
            ))
            .labelsHidden()
            #endif
        }
        .padding(theme.spacing.md)
        .background(theme.colors.surfaceAlt)
        .clipShape(.rect(cornerRadius: RadiusTokens.inline))
    }
}
