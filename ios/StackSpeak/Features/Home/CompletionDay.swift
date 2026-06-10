import Foundation

struct CompletionDay: Identifiable {
    let date: Date
    /// 0...1 — fraction of the day's daily set that was practiced.
    let progress: Double
    let isToday: Bool

    var id: Date { date }
    var isComplete: Bool { progress >= 1.0 }
    var hasAnyProgress: Bool { progress > 0 }
}

/// Ten-day streak strip. Each cell stacks a day-of-week initial, a 22pt
/// rounded square that fills bottom-up by completion progress, and the
/// date number. Today is anchored with an accent ring on the cell.
///
/// Design references: Apple Fitness weekly view (day-letter + cell + date),
/// Duolingo streak calendar (warm flame color for filled days, today
/// emphasized), Streaks app (partial fill encodes progress not just
/// done/not-done). Color choice: `streak` (warm amber) ties visually to
/// the flame in the status line above; `good` (green) was reserved for
/// "you got an answer right" elsewhere in the app.
