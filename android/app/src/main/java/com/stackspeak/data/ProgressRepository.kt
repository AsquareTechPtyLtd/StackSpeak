package com.stackspeak.data

import com.stackspeak.data.local.ProgressLocalStore
import com.stackspeak.domain.Progression
import com.stackspeak.domain.Sm2
import com.stackspeak.domain.Sm2State
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Instant
import java.time.ZoneId
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Single source of truth for [UserProgress]: loads it from Room, exposes it as a
 * StateFlow, and applies the pure [Progression] mutations, persisting after each.
 */
@Singleton
class ProgressRepository @Inject constructor(private val store: ProgressLocalStore) {
    private val mutex = Mutex()
    private val _state = MutableStateFlow<UserProgress?>(null)
    val state: StateFlow<UserProgress?> = _state.asStateFlow()

    suspend fun ensureLoaded(): UserProgress = mutex.withLock {
        _state.value?.let { return it }
        val loaded = store.load() ?: UserProgress(shuffleSeed = UUID.randomUUID().toString().uppercase())
        _state.value = loaded
        loaded
    }

    private suspend fun mutate(transform: (UserProgress) -> UserProgress): UserProgress {
        val current = ensureLoaded()
        val next = transform(current)
        mutex.withLock { _state.value = next }
        store.save(next)
        return next
    }

    suspend fun completeOnboarding(stacks: Set<String>) = mutate {
        it.copy(selectedStacks = stacks, didCompleteOnboarding = true)
    }

    suspend fun setCursor(cursor: Int) = mutate { it.copy(wordQueueCursor = cursor) }

    suspend fun recordPractice(wordId: String, sentence: String, inputMethod: String, now: Instant = Instant.now()) =
        mutate { Progression.recordPractice(it, wordId, sentence, inputMethod, now) }

    suspend fun recordAssessment(
        wordId: String, isCorrect: Boolean, selected: String, correct: String, now: Instant = Instant.now(),
    ) = mutate { Progression.recordAssessment(it, wordId, isCorrect, selected, correct, now) }

    suspend fun registerDailyCompletion(now: Instant = Instant.now(), zone: ZoneId = ZoneId.systemDefault()) =
        mutate { Progression.registerDailyCompletion(it, now, zone) }

    suspend fun markMastered(wordId: String) = mutate { it.copy(masteredWordIds = it.masteredWordIds + wordId) }

    suspend fun markBookCardRead(bookId: String, cardId: String, now: Instant = Instant.now(), zone: ZoneId = ZoneId.systemDefault()) =
        mutate { Progression.recordBookCardRead(it, bookId, cardId, now, zone) }

    suspend fun bookProgress(bookId: String): BookProgressRecord? =
        ensureLoaded().bookProgress.firstOrNull { it.bookId == bookId }

    suspend fun setDailyGoal(goal: Int) = mutate { it.copy(dailyWordGoal = maxOf(3, goal)) }

    /** Applies an SM-2 grade to a word's review state (creating it if absent). */
    suspend fun gradeReview(wordId: String, quality: Int, now: Instant = Instant.now()) = mutate { p ->
        val existing = p.reviewStates.firstOrNull { it.wordId == wordId }
        val before = existing?.let { Sm2State(it.easinessFactor, it.interval, it.repetitions, it.dueDate, it.lastReviewedAt) }
            ?: Sm2.initial(now)
        val after = Sm2.updateAfterReview(before, wordId, quality, now)
        val record = ReviewRecord(wordId, after.easinessFactor, after.interval, after.repetitions, after.dueDate, after.lastReviewedAt)
        p.copy(reviewStates = p.reviewStates.filter { it.wordId != wordId } + record)
    }
}
