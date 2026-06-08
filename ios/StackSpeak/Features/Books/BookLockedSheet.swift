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
                    .font(.system(size: 48, weight: .semibold))
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
            VStack(alignment: .leading, spacing: 2) {
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
                    progress.isPro = on
                    progress.proExpiryDate = on
                        ? Calendar.current.date(byAdding: .year, value: 1, to: Date())
                        : nil
                    do {
                        try modelContext.save()
                        if on { dismiss() }
                    } catch {
                        progress.isPro = !on
                        progress.proExpiryDate = nil
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
