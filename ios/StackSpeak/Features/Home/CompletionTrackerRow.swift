import SwiftUI

// MARK: - 10-day completion tracker

struct CompletionTrackerRow: View {
    @Environment(\.theme) private var theme

    let days: [CompletionDay]

    private static let cellSize: CGFloat = 22
    private static let cellRadius: CGFloat = RadiusTokens.inline

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(days) { day in
                cell(for: day)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private func cell(for day: CompletionDay) -> some View {
        VStack(spacing: theme.spacing.xs) {
            Text(dayLetter(for: day.date))
                .font(TypographyTokens.mono)
                .foregroundColor(day.isToday ? theme.colors.accent : theme.colors.inkFaint)

            ZStack(alignment: .bottom) {
                // Empty surface
                RoundedRectangle(cornerRadius: Self.cellRadius)
                    .fill(theme.colors.surfaceAlt)

                // Bottom-up fill proportional to day's completion (Apple Fitness ring vibe).
                if day.hasAnyProgress {
                    RoundedRectangle(cornerRadius: Self.cellRadius)
                        .fill(day.isComplete
                              ? theme.colors.streak
                              : theme.colors.streak.opacity(0.45))
                        .frame(height: Self.cellSize * CGFloat(day.progress))
                }

                if day.isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundColor(theme.colors.streakInk)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: Self.cellSize, height: Self.cellSize)
            .clipShape(.rect(cornerRadius: Self.cellRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Self.cellRadius)
                    // Today's border stays in the streak family — an indigo
                    // accent ring around an orange fill collides two semantic
                    // color families in one cell.
                    .strokeBorder(
                        day.isToday ? theme.colors.streak
                                    : (day.hasAnyProgress ? theme.colors.streak.opacity(0.8) : theme.colors.line),
                        lineWidth: day.isToday ? BorderTokens.emphasis : BorderTokens.hairline
                    )
            )

            Text(dayNumber(for: day.date))
                .font(TypographyTokens.mono)
                .foregroundColor(day.isToday ? theme.colors.ink : theme.colors.inkFaint)
        }
    }

    // MARK: - Date formatting

    private func dayLetter(for date: Date) -> String {
        // First letter of the localized weekday (e.g. "M", "T", "W").
        // `veryShortWeekdaySymbols` returns single characters per locale.
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols
        let weekdayIndex = cal.component(.weekday, from: date) - 1
        guard weekdayIndex >= 0, weekdayIndex < symbols.count else { return "" }
        return symbols[weekdayIndex]
    }

    private func dayNumber(for date: Date) -> String {
        let cal = Calendar.current
        return "\(cal.component(.day, from: date))"
    }

    private var accessibilitySummary: String {
        let completed = days.filter { $0.isComplete }.count
        return String(format: String(localized: "home.tracker.accessibility.format"),
                      completed, days.count)
    }
}

// MARK: - Previews

private func previewDays() -> [CompletionDay] {
    let calendar = Calendar.current
    return (0..<10).map { offset in
        let date = calendar.date(byAdding: .day, value: -(9 - offset), to: Date()) ?? Date()
        let progress: Double
        switch offset {
        case 0...5: progress = 1.0       // complete days
        case 6:     progress = 0.6       // partial day
        case 7:     progress = 0.0       // missed day
        case 8:     progress = 1.0       // complete
        default:    progress = 0.0       // today — no progress yet
        }
        return CompletionDay(date: date, progress: progress, isToday: offset == 9)
    }
}

#Preview("CompletionTrackerRow — Light") {
    CompletionTrackerRow(days: previewDays())
        .padding()
        .withTheme(ThemeManager())
}

#Preview("CompletionTrackerRow — Dark") {
    CompletionTrackerRow(days: previewDays())
        .padding()
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
