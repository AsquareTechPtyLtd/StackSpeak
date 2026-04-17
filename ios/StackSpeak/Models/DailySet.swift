import Foundation
import SwiftData

@Model
final class DailySet {
    @Attribute(.unique) var date: Date
    var wordIds: [UUID]
    var completedWordIds: Set<UUID>

    var isComplete: Bool {
        completedWordIds.count == wordIds.count && !wordIds.isEmpty
    }

    var progress: Double {
        guard !wordIds.isEmpty else { return 0 }
        return Double(completedWordIds.count) / Double(wordIds.count)
    }

    init(date: Date, wordIds: [UUID]) {
        self.date = Calendar.current.startOfDay(for: date)
        self.wordIds = wordIds
        self.completedWordIds = []
    }

    func markWordCompleted(_ wordId: UUID) {
        completedWordIds.insert(wordId)
    }

    func isWordCompleted(_ wordId: UUID) -> Bool {
        completedWordIds.contains(wordId)
    }
}
