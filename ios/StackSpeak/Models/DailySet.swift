import Foundation
import SwiftData

@Model
final class DailySet {
    @Attribute(.unique) var dayString: String
    var wordIdsStorage: String
    var completedWordIdsStorage: String

    /// Additional 5-card batches loaded by Pro users via the load-more affordance.
    /// Encoded as semicolon-separated batches of CSV UUIDs:
    /// `"id1,id2,id3,id4,id5;id6,id7,id8,id9,id10"`. Empty string when no batches.
    var additionalBatchesStorage: String = ""

    var wordIds: [UUID] {
        get {
            guard !wordIdsStorage.isEmpty else { return [] }
            return wordIdsStorage.components(separatedBy: ",").compactMap { UUID(uuidString: $0) }
        }
        set {
            wordIdsStorage = newValue.map(\.uuidString).joined(separator: ",")
        }
    }

    var completedWordIds: Set<UUID> {
        get {
            guard !completedWordIdsStorage.isEmpty else { return [] }
            return Set(completedWordIdsStorage.components(separatedBy: ",").compactMap { UUID(uuidString: $0) })
        }
        set {
            completedWordIdsStorage = newValue.map(\.uuidString).joined(separator: ",")
        }
    }

    var additionalBatches: [[UUID]] {
        get {
            guard !additionalBatchesStorage.isEmpty else { return [] }
            return additionalBatchesStorage
                .components(separatedBy: ";")
                .map { batch in
                    batch.components(separatedBy: ",").compactMap { UUID(uuidString: $0) }
                }
                .filter { !$0.isEmpty }
        }
        set {
            additionalBatchesStorage = newValue
                .map { batch in batch.map(\.uuidString).joined(separator: ",") }
                .joined(separator: ";")
        }
    }

    /// All vocab card IDs served today across the daily-5 + any additional batches.
    /// Use as the exclusion set when selecting the next batch.
    var allServedWordIds: Set<UUID> {
        var s = Set(wordIds)
        for batch in additionalBatches { s.formUnion(batch) }
        return s
    }

    var isComplete: Bool {
        completedWordIds.count == wordIds.count && !wordIds.isEmpty
    }

    /// Streak completion is anchored to the first 5 cards regardless of tier.
    /// Pro's additional batches do not delay or accelerate streak completion.
    var isStreakComplete: Bool {
        !wordIds.isEmpty && wordIds.allSatisfy { completedWordIds.contains($0) }
    }

    var progress: Double {
        guard !wordIds.isEmpty else { return 0 }
        return Double(completedWordIds.count) / Double(wordIds.count)
    }

    init(dayString: String, wordIds: [UUID]) {
        self.dayString = dayString
        self.wordIdsStorage = wordIds.map(\.uuidString).joined(separator: ",")
        self.completedWordIdsStorage = ""
        self.additionalBatchesStorage = ""
    }

    /// Appends a Pro load-more batch. No-ops if `batch` is empty.
    func appendAdditionalBatch(_ batch: [UUID]) {
        guard !batch.isEmpty else { return }
        var batches = additionalBatches
        batches.append(batch)
        additionalBatches = batches
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
