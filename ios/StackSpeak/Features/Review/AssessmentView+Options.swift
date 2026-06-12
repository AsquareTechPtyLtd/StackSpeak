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

    /// Picks plausible wrong-answer definitions for the four-option quiz.
    ///
    /// Two properties matter for a fair question:
    /// 1. No distractor may be a *second correct answer*. A word that shares the
    ///    target's term (e.g. "CAP Theorem" appearing in several stacks) carries
    ///    a differently-worded but still-correct definition — excluding by id and
    ///    verbatim definition alone misses it, so we also exclude by normalized
    ///    term.
    /// 2. Distractors should be *plausible*. Drawing at random surfaces a Scrum
    ///    definition against a cryptography term, which is eliminable without
    ///    knowing the answer. We rank candidates by topical affinity (same stack,
    ///    then category, then a shared tag) and prefer words the user has
    ///    practiced, falling through to anything unlocked so the four options
    ///    almost always fill.
    static func buildDistractors(for word: Word, count: Int,
                                 allWords: [Word], progress: UserProgress) -> [String] {
        let targetTerm = normalizedTerm(word.word)
        let targetTags = Set(word.tags)
        let practicedIds = progress.wordsPracticedIds

        func isCandidate(_ w: Word) -> Bool {
            w.id != word.id
                && w.unlockLevel <= progress.level
                && !w.shortDefinition.isEmpty
                && w.shortDefinition != word.shortDefinition
                && normalizedTerm(w.word) != targetTerm
        }

        // Lower key = better distractor. Tier on topical closeness, then prefer
        // already-practiced vocabulary within each tier.
        func sortKey(_ w: Word) -> Int {
            let tier: Int
            if w.stack == word.stack {
                tier = 0
            } else if w.category == word.category {
                tier = 1
            } else if !targetTags.isDisjoint(with: Set(w.tags)) {
                tier = 2
            } else {
                tier = 3
            }
            return tier * 2 + (practicedIds.contains(w.id) ? 0 : 1)
        }

        // Pre-shuffle so ties within a (tier, practiced) bucket are random;
        // `sorted` is not stable, so equal keys stay shuffled.
        let ordered = allWords.filter(isCandidate).shuffled().sorted { sortKey($0) < sortKey($1) }

        var seen = Set<String>()
        var result: [String] = []
        for candidate in ordered where seen.insert(candidate.shortDefinition).inserted {
            result.append(candidate.shortDefinition)
            if result.count == count { break }
        }
        return result
    }

    /// Lowercased, punctuation-stripped term used to detect same-concept words
    /// across stacks (mirrors the data-tooling normalization): drop
    /// parentheticals, split on any non-alphanumeric, rejoin with single spaces.
    /// e.g. "B+ Tree" and "Cache-Control (header)" → "b tree" / "cache control".
    static func normalizedTerm(_ s: String) -> String {
        let withoutParens = s.replacingOccurrences(
            of: #"\([^)]*\)"#, with: "", options: .regularExpression)
        return withoutParens
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: " ")
    }
}
