package com.stackspeak.domain

import com.stackspeak.domain.ProgressSnapshot.AssessmentResultDTO
import com.stackspeak.domain.ProgressSnapshot.BookProgressDTO
import com.stackspeak.domain.ProgressSnapshot.PracticedSentenceDTO
import com.stackspeak.domain.ProgressSnapshot.ReviewStateDTO
import java.time.Instant

/**
 * Reconciles two snapshots that diverged offline — ported from iOS
 * `ProgressSnapshot+Merge.swift`. Per-field strategy (must match `merge.json`):
 *  - Monotonic-progress sets union + sort ascending.
 *  - Preferences (bookmarks, selectedStacks, dailyWordGoal) + paired rotation
 *    state (shuffleSeed + wordQueueCursor) are last-write-wins from the side with
 *    the later `updatedAt` — union would resurrect intentional deletions, and a
 *    cursor only indexes into its own seed's shuffle.
 *  - Counters (level, longestStreak) take the max; currentStreak follows the
 *    later `lastCompletedDate`.
 *  - Sub-records merge by identity (see helpers). Deterministic + idempotent.
 */
fun mergeSnapshots(local: ProgressSnapshot, remote: ProgressSnapshot): ProgressSnapshot {
    val localNewerCompletion =
        (local.lastCompletedDate ?: Instant.MIN) >= (remote.lastCompletedDate ?: Instant.MIN)
    val recentSide = if (localNewerCompletion) local else remote
    val newerByUpdate = if (local.updatedAt >= remote.updatedAt) local else remote

    return ProgressSnapshot(
        schemaVersion = maxOf(local.schemaVersion, remote.schemaVersion),
        updatedAt = maxOf(local.updatedAt, remote.updatedAt),
        level = maxOf(local.level, remote.level),
        currentStreak = recentSide.currentStreak,
        longestStreak = maxOf(local.longestStreak, remote.longestStreak),
        lastCompletedDate = latest(local.lastCompletedDate, remote.lastCompletedDate),
        didCompleteOnboarding = local.didCompleteOnboarding || remote.didCompleteOnboarding,
        practicedWordIds = union(local.practicedWordIds, remote.practicedWordIds),
        masteredWordIds = union(local.masteredWordIds, remote.masteredWordIds),
        bookmarkedWordIds = newerByUpdate.bookmarkedWordIds,
        wordsWithTwoCorrectIds = union(local.wordsWithTwoCorrectIds, remote.wordsWithTwoCorrectIds),
        wordsCreditedForLevelIds = union(local.wordsCreditedForLevelIds, remote.wordsCreditedForLevelIds),
        selectedStacks = newerByUpdate.selectedStacks,
        shuffleSeed = newerByUpdate.shuffleSeed,
        wordQueueCursor = newerByUpdate.wordQueueCursor,
        dailyWordGoal = newerByUpdate.dailyWordGoal,
        reviewStates = mergeReviewStates(local.reviewStates, remote.reviewStates),
        assessmentResults = mergeById(local.assessmentResults, remote.assessmentResults) { it.id },
        practicedSentences = mergeSentences(local.practicedSentences, remote.practicedSentences),
        bookProgress = mergeBooks(local.bookProgress, remote.bookProgress),
    )
}

private fun union(a: List<String>, b: List<String>): List<String> =
    (a + b).toSet().sorted()

private fun latest(a: Instant?, b: Instant?): Instant? = when {
    a != null && b != null -> maxOf(a, b)
    else -> a ?: b
}

/** Keep the per-word SRS state reviewed most recently (later lastReviewedAt, then later dueDate). */
private fun mergeReviewStates(a: List<ReviewStateDTO>, b: List<ReviewStateDTO>): List<ReviewStateDTO> {
    val byWord = LinkedHashMap<String, ReviewStateDTO>()
    for (s in a + b) {
        val existing = byWord[s.wordId]
        byWord[s.wordId] = if (existing == null) s else moreRecent(existing, s)
    }
    return byWord.values.sortedBy { it.wordId }
}

private fun moreRecent(x: ReviewStateDTO, y: ReviewStateDTO): ReviewStateDTO {
    val xr = x.lastReviewedAt ?: Instant.MIN
    val yr = y.lastReviewedAt ?: Instant.MIN
    if (xr != yr) return if (xr > yr) x else y
    return if (x.dueDate >= y.dueDate) x else y
}

/** Identical ids are the same event; later write (b over a) wins, then sort by id. */
private fun <T> mergeById(a: List<T>, b: List<T>, id: (T) -> String): List<T> {
    val byId = LinkedHashMap<String, T>()
    for (item in a + b) byId[id(item)] = item
    return byId.values.sortedBy { id(it) }
}

/** No id — dedupe by (wordId, whole-second epoch, sentence); whole seconds because ISO-8601 drops sub-second. */
private fun mergeSentences(a: List<PracticedSentenceDTO>, b: List<PracticedSentenceDTO>): List<PracticedSentenceDTO> {
    fun key(s: PracticedSentenceDTO) = "${s.wordId}|${s.createdAt.epochSecond}|${s.sentence}"
    val seen = HashSet<String>()
    val out = ArrayList<PracticedSentenceDTO>()
    for (s in (a + b).sortedBy { it.createdAt }) {
        if (seen.add(key(s))) out.add(s)
    }
    return out
}

/** Per book: union completed cards, max streaks, keep the most-recently-opened position. */
private fun mergeBooks(a: List<BookProgressDTO>, b: List<BookProgressDTO>): List<BookProgressDTO> {
    val byBook = LinkedHashMap<String, BookProgressDTO>()
    for (book in a + b) {
        val existing = byBook[book.bookId]
        if (existing == null) {
            byBook[book.bookId] = book
            continue
        }
        val newer = if (book.lastOpenedAt >= existing.lastOpenedAt) book else existing
        val older = if (book.lastOpenedAt >= existing.lastOpenedAt) existing else book
        byBook[book.bookId] = BookProgressDTO(
            bookId = book.bookId,
            lastOpenedAt = newer.lastOpenedAt,
            currentChapterId = newer.currentChapterId,
            currentCardId = newer.currentCardId,
            completedCardIds = (existing.completedCardIds + book.completedCardIds).toSet().sorted(),
            lastReadingDayString = maxOf(newer.lastReadingDayString, older.lastReadingDayString),
            currentStreakDays = newer.currentStreakDays,
            longestStreakDays = maxOf(existing.longestStreakDays, book.longestStreakDays),
        )
    }
    return byBook.values.sortedBy { it.bookId }
}
