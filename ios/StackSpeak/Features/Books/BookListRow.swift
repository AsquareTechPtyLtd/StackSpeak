import SwiftUI

/// A row in the Books tab catalog. Reads its lock state and per-book progress
/// from the parent ViewModel; pure presentation otherwise.
struct BookListRow: View {
    @Environment(\.theme) private var theme

    let book: BookSummary
    let lockState: BookLockState
    let currentStreak: Int?
    let completionRatio: Double?

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            cover
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                titleRow
                Text(book.summary)
                    .font(TypographyTokens.subheadline)
                    .foregroundColor(theme.colors.inkMuted)
                    .lineLimit(2)
                metaRow
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var cover: some View {
        Image(systemName: book.coverIcon)
            .font(.system(.title2, weight: .regular))
            .foregroundColor(coverTint)
            .frame(width: 44, height: 44)
            .background(coverTint.opacity(0.1))
            .clipShape(.rect(cornerRadius: RadiusTokens.inline))
            .accessibilityHidden(true)
    }

    private var coverTint: Color {
        if let hex = book.accentHex { return Color(hex: hex) }
        return theme.colors.accent
    }

    private var titleRow: some View {
        HStack(spacing: theme.spacing.xs) {
            Text(book.title)
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.ink)
                .lineLimit(2)
            Spacer()
            badge
        }
    }

    @ViewBuilder
    private var badge: some View {
        switch lockState {
        case .free:
            BookBadge(text: "books.badge.free", tint: theme.colors.good)
        case .locked:
            BookBadge(text: "books.badge.pro", tint: theme.colors.accent, leadingIcon: "lock.fill")
        case .unlocked:
            EmptyView()
        }
    }

    private var metaRow: some View {
        HStack(spacing: theme.spacing.sm) {
            Text(String(format: String(localized: "books.meta.format"), book.chapterCount, book.cardCount))
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.inkFaint)
            if let streak = currentStreak, streak >= 2 {
                Spacer()
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(theme.colors.streak)
                    Text(String(format: String(localized: "books.streak.day.format"), streak))
                        .font(TypographyTokens.caption)
                        .foregroundColor(theme.colors.inkMuted)
                }
                .accessibilityLabel(String(format: String(localized: "a11y.book.streak.format"), streak))
            } else if let ratio = completionRatio, ratio > 0 {
                Spacer()
                Text(String(format: String(localized: "books.completion.format"), Int(ratio * 100)))
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkMuted)
            }
        }
    }
}

private struct BookBadge: View {
    @Environment(\.theme) private var theme
    let text: LocalizedStringKey
    let tint: Color
    var leadingIcon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon = leadingIcon {
                Image(systemName: icon).font(.system(.caption2, weight: .semibold))
            }
            Text(text)
                .font(TypographyTokens.caption.weight(.semibold))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tint.opacity(0.12))
        .clipShape(.rect(cornerRadius: RadiusTokens.pill))
    }
}
