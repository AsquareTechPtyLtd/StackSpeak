import Foundation
import SwiftData

@Model
final class DailySet {
    /// ISO-8601 date string in the user's local calendar ("YYYY-MM-DD").
    /// Using a string key avoids Date equality precision issues and timezone drift.
    @Attribute(.unique) var dayString: String
    var wordIds: [UUID]
    var completedWordIds: Set<UUID>

    var isComplete: Bool {
        completedWordIds.count == wordIds.count && !wordIds.isEmpty
    }

    var progress: Double {
        guard !wordIds.isEmpty else { return 0 }
        return Double(completedWordIds.count) / Double(wordIds.count)
    }

    init(dayString: String, wordIds: [UUID]) {
        self.dayString = dayString
        self.wordIds = wordIds
        self.completedWordIds = []
    }

    func markWordCompleted(_ wordId: UUID) {
        var updated = completedWordIds
        updated.insert(wordId)
        completedWordIds = updated
    }

    func isWordCompleted(_ wordId: UUID) -> Bool {
        completedWordIds.contains(wordId)
    }

    static func todayString() -> String {
        dayString(from: Date())
    }

    static func dayString(from date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
