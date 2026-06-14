import Foundation

// Merge strategy: reconciling two devices that diverged offline must never lose
// monotonic progress (mastered words, streaks, SRS intervals) — those sets union
// and counters take the max. User preferences (bookmarks, selected stacks) and
// paired rotation state (seed + cursor) use last-write-wins from newerByUpdate.
// Pure and deterministic — heavily unit-tested.
extension ProgressSnapshot {
    static func merge(local: ProgressSnapshot, remote: ProgressSnapshot) -> ProgressSnapshot {
        // Streak is tied to lastCompletedDate, so take the streak from whichever
        // side completed more recently; longest streak is a high-water mark → max.
        let localNewer = (local.lastCompletedDate ?? .distantPast) >= (remote.lastCompletedDate ?? .distantPast)
        let recentSide = localNewer ? local : remote
        // Rotation state: both seed and cursor come from the more recently written side
        // so they stay paired — mixing seed from one side with cursor from the other
        // would index the wrong position in the shuffle.
        let newerByUpdate = local.updatedAt >= remote.updatedAt ? local : remote

        return ProgressSnapshot(
            schemaVersion: max(local.schemaVersion, remote.schemaVersion),
            updatedAt: max(local.updatedAt, remote.updatedAt),
            level: max(local.level, remote.level),
            currentStreak: recentSide.currentStreak,
            longestStreak: max(local.longestStreak, remote.longestStreak),
            lastCompletedDate: latest(local.lastCompletedDate, remote.lastCompletedDate),
            didCompleteOnboarding: local.didCompleteOnboarding || remote.didCompleteOnboarding,
            practicedWordIds: union(local.practicedWordIds, remote.practicedWordIds),
            masteredWordIds: union(local.masteredWordIds, remote.masteredWordIds),
            // H1: bookmarks are a user preference, not monotonic progress — union would
            // permanently prevent un-bookmarking. Use last-write-wins instead.
            bookmarkedWordIds: newerByUpdate.bookmarkedWordIds,
            wordsWithTwoCorrectIds: union(local.wordsWithTwoCorrectIds, remote.wordsWithTwoCorrectIds),
            wordsCreditedForLevelIds: union(local.wordsCreditedForLevelIds, remote.wordsCreditedForLevelIds),
            // H2: stack selection is a preference — union reverses intentional deselection.
            selectedStacks: newerByUpdate.selectedStacks,
            // LOW: keep shuffleSeed and wordQueueCursor from the same side so the cursor
            // indexes the correct shuffle. Pairing the winning seed with the max cursor
            // from the other seed would produce wrong word ordering.
            shuffleSeed: newerByUpdate.shuffleSeed,
            wordQueueCursor: newerByUpdate.wordQueueCursor,
            // Preference — last-write-wins, like bookmarks/selectedStacks above.
            dailyWordGoal: newerByUpdate.dailyWordGoal,
            reviewStates: mergeReviewStates(local.reviewStates, remote.reviewStates),
            assessmentResults: mergeById(local.assessmentResults, remote.assessmentResults, id: \.id),
            practicedSentences: mergeSentences(local.practicedSentences, remote.practicedSentences),
            bookProgress: mergeBooks(local.bookProgress, remote.bookProgress)
        )
    }

    // MARK: - Helpers

    private static func union(_ a: [String], _ b: [String]) -> [String] {
        Array(Set(a).union(b)).sorted()
    }

    private static func latest(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) {
        case let (x?, y?): return max(x, y)
        default: return a ?? b
        }
    }

    /// Keep the per-word SRS state that was reviewed most recently (a later
    /// `lastReviewedAt`, falling back to a later `dueDate`).
    private static func mergeReviewStates(_ a: [ReviewStateDTO], _ b: [ReviewStateDTO]) -> [ReviewStateDTO] {
        var byWord: [String: ReviewStateDTO] = [:]
        for s in a + b {
            if let existing = byWord[s.wordId] {
                byWord[s.wordId] = moreRecent(existing, s)
            } else {
                byWord[s.wordId] = s
            }
        }
        return byWord.values.sorted { $0.wordId < $1.wordId }
    }

    private static func moreRecent(_ x: ReviewStateDTO, _ y: ReviewStateDTO) -> ReviewStateDTO {
        let xr = x.lastReviewedAt ?? .distantPast
        let yr = y.lastReviewedAt ?? .distantPast
        if xr != yr { return xr > yr ? x : y }
        return x.dueDate >= y.dueDate ? x : y
    }

    private static func mergeById<T>(_ a: [T], _ b: [T], id: (T) -> String) -> [T] {
        var byId: [String: T] = [:]
        for item in a + b { byId[id(item)] = item }  // identical ids are the same event
        return byId.values.sorted { id($0) < id($1) }
    }

    /// Practiced sentences have no id; dedupe by (word, timestamp, text).
    /// C1: Use whole-second timestamps in the key because ISO-8601 encoding (used
    /// by JSONEncoder) truncates to whole seconds — sub-second floats would never
    /// match the decoded value and every sync would re-append all sentences.
    private static func mergeSentences(_ a: [PracticedSentenceDTO], _ b: [PracticedSentenceDTO]) -> [PracticedSentenceDTO] {
        func key(_ s: PracticedSentenceDTO) -> String {
            "\(s.wordId)|\(Int(s.createdAt.timeIntervalSince1970))|\(s.sentence)"
        }
        var seen = Set<String>()
        var out: [PracticedSentenceDTO] = []
        for s in (a + b).sorted(by: { $0.createdAt < $1.createdAt }) {
            if seen.insert(key(s)).inserted { out.append(s) }
        }
        return out
    }

    /// Per book: union completed cards, max streaks, keep the most recently opened position.
    private static func mergeBooks(_ a: [BookProgressDTO], _ b: [BookProgressDTO]) -> [BookProgressDTO] {
        var byBook: [String: BookProgressDTO] = [:]
        for book in a + b {
            guard let existing = byBook[book.bookId] else { byBook[book.bookId] = book; continue }
            let newer = book.lastOpenedAt >= existing.lastOpenedAt ? book : existing
            let older = book.lastOpenedAt >= existing.lastOpenedAt ? existing : book
            byBook[book.bookId] = BookProgressDTO(
                bookId: book.bookId,
                lastOpenedAt: newer.lastOpenedAt,
                currentChapterId: newer.currentChapterId,
                currentCardId: newer.currentCardId,
                completedCardIds: Array(Set(existing.completedCardIds).union(book.completedCardIds)).sorted(),
                lastReadingDayString: max(newer.lastReadingDayString, older.lastReadingDayString),
                currentStreakDays: newer.currentStreakDays,
                longestStreakDays: max(existing.longestStreakDays, book.longestStreakDays)
            )
        }
        return byBook.values.sorted { $0.bookId < $1.bookId }
    }
}
