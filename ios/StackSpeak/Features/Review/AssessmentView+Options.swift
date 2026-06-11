import SwiftData
import SwiftUI
import OSLog

private let logger = Logger(category: "AssessmentView")

// Multiple-choice option generation — split out per the
// <TypeName>+<Concern>.swift convention to keep the primary file under the
// size limit. All stored properties live in `AssessmentView.swift`.
extension AssessmentView {
    func generateOptions() {
        guard let progress = userProgress else { return }
        let allWords: [Word]
        do {
            allWords = try modelContext.fetch(FetchDescriptor<Word>())
        } catch {
            logger.error("Failed to fetch words for assessment options: \(error.localizedDescription, privacy: .public)")
            return
        }

        let distractors = Self.buildDistractors(for: word, count: Self.distractorCount,
                                                allWords: allWords, progress: progress)
        var seen = Set<String>()
        options = ([word.shortDefinition] + distractors)
            .filter { seen.insert($0).inserted }
            .shuffled()
    }

    /// Picks plausible wrong-answer definitions: prefers words the user has practiced,
    /// falls back to any unlocked word at the user's current level.
    private static func buildDistractors(for word: Word, count: Int,
                                         allWords: [Word], progress: UserProgress) -> [String] {
        func excludesTarget(_ w: Word) -> Bool {
            w.id != word.id && w.shortDefinition != word.shortDefinition
        }
        let practiced = allWords.filter { excludesTarget($0) && progress.wordsPracticedIds.contains($0.id) }
        let pool = practiced.count >= count
            ? practiced
            : allWords.filter { excludesTarget($0) && $0.unlockLevel <= progress.level }
        return pool.shuffled().prefix(count).map(\.shortDefinition)
    }
}
