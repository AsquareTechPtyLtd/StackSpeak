import Foundation
import SwiftData

// Today's-set reshaping for WordService — split out per the
// <TypeName>+<Concern>.swift convention. These two methods mutate the current
// day's `DailySet` in place (and may advance `wordQueueCursor`) when the daily
// goal or the stack selection changes, always preserving already-completed work.
extension WordService {
    /// Sets the daily word goal and reshapes today's set in place so the change
    /// takes effect immediately: growing appends fresh qualifying words from the
    /// queue, shrinking trims to the new size. The `DailySet`'s completion set is
    /// preserved, and on shrink completed words are kept ahead of incomplete ones
    /// so already-practiced work never disappears from today's count.
    @discardableResult
    func setDailyWordGoal(_ goal: Int, userProgress: UserProgress) throws -> DailySet {
        let clamped = max(Self.minDailyWordGoal, goal)
        userProgress.dailyWordGoal = clamped

        let dayString = DailySet.todayString()
        let descriptor = FetchDescriptor<DailySet>(predicate: #Predicate { $0.dayString == dayString })
        guard let set = try modelContext.fetch(descriptor).first, !set.wordIds.isEmpty else {
            // Nothing generated yet today — produce a fresh set at the new goal.
            return try generateDailySet(for: Date(), userProgress: userProgress)
        }

        let current = set.wordIds
        if clamped > current.count {
            let allWords = try modelContext.fetch(FetchDescriptor<Word>())
            let shuffled = deterministicShuffle(allWords, seed: userProgress.shuffleSeed)
            // Exclude words already in the set so a near-exhausted pool doesn't
            // hand back duplicates (which we'd drop) while still advancing the cursor.
            let (more, newCursor) = selectQualifyingWords(
                from: shuffled,
                startingAt: userProgress.wordQueueCursor,
                userProgress: userProgress,
                count: clamped - current.count,
                excludeIds: Set(current)
            )
            guard !more.isEmpty else { return set }   // nothing new qualified — leave the set untouched
            set.wordIds = current + more.map(\.id)
            userProgress.wordQueueCursor = newCursor
            try modelContext.save()
        } else if clamped < current.count {
            // Order completed words to the front before trimming so finished work
            // is never the part that gets dropped.
            let done = set.completedWordIds
            let reordered = current.filter { done.contains($0) } + current.filter { !done.contains($0) }
            set.wordIds = Array(reordered.prefix(clamped))
            try modelContext.save()
        }

        return set
    }

    /// Reconciles today's set with the current stack selection (call right after
    /// the user changes stacks). Completed words are always kept — never disturb
    /// finished work — but incomplete words that no longer qualify (deselected
    /// stack, now mastered/locked) are dropped and backfilled with fresh
    /// qualifying words so the set stays at the daily goal. Returns the updated
    /// set, or nil when there's nothing to reconcile.
    @discardableResult
    func reconcileTodaysSetWithSelection(userProgress: UserProgress) throws -> DailySet? {
        let dayString = DailySet.todayString()
        let descriptor = FetchDescriptor<DailySet>(predicate: #Predicate { $0.dayString == dayString })
        guard let set = try modelContext.fetch(descriptor).first, !set.wordIds.isEmpty else { return nil }

        let allWords = try modelContext.fetch(FetchDescriptor<Word>())
        guard !allWords.isEmpty else { return nil }
        let wordsById = Dictionary(allWords.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let completed = set.completedWordIds
        let activeStacks = userProgress.effectiveSelectedStacks

        // Keep completed words and incomplete words that still qualify (preserve
        // order); drop incomplete words that fell out of the new selection. Reuses
        // the shared `qualifies` so the rule can't drift from selection.
        var kept: [UUID] = []
        for id in set.wordIds {
            let stillQualifies = wordsById[id].map { qualifies(word: $0, for: userProgress, activeStacks: activeStacks) } ?? false
            if completed.contains(id) || stillQualifies {
                kept.append(id)
            }
        }

        var changed = kept.count != set.wordIds.count
        let goal = Self.effectiveDailyGoal(userProgress)
        if kept.count < goal {
            let shuffled = deterministicShuffle(allWords, seed: userProgress.shuffleSeed)
            let (more, newCursor) = selectQualifyingWords(
                from: shuffled,
                startingAt: userProgress.wordQueueCursor,
                userProgress: userProgress,
                count: goal - kept.count,
                excludeIds: Set(kept)
            )
            if !more.isEmpty {
                kept += more.map(\.id)
                userProgress.wordQueueCursor = newCursor
                changed = true
            }
        }

        guard changed else { return set }
        set.wordIds = kept
        try modelContext.save()
        return set
    }
}
