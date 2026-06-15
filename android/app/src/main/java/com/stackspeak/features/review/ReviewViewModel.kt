package com.stackspeak.features.review

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.stackspeak.data.ProgressRepository
import com.stackspeak.data.WordRepository
import com.stackspeak.data.content.Word
import com.stackspeak.domain.AssessmentDistractors
import com.stackspeak.domain.Progression
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import javax.inject.Inject

/** Assessment (MCQ, credits levels) + Flashcards (SM-2). Both run offline. */
@HiltViewModel
class ReviewViewModel @Inject constructor(
    private val words: WordRepository,
    private val progress: ProgressRepository,
) : ViewModel() {

    enum class Mode { ASSESSMENT, FLASHCARDS }

    data class Question(val word: Word, val options: List<String>, val correct: String)

    data class UiState(
        val loading: Boolean = true,
        val mode: Mode = Mode.ASSESSMENT,
        val question: Question? = null,
        val lastAnswerCorrect: Boolean? = null,
        val flashcard: Word? = null,
        val flashcardRevealed: Boolean = false,
        val assessmentRemaining: Int = 0,
        val flashcardsRemaining: Int = 0,
    )

    private val _state = MutableStateFlow(UiState())
    val state = _state.asStateFlow()

    private var assessmentQueue = ArrayDeque<String>()
    private var flashcardQueue = ArrayDeque<String>()
    private var seed = ""

    fun load() = viewModelScope.launch {
        val p = progress.ensureLoaded()
        seed = p.shuffleSeed
        val now = Instant.now()
        val zone = ZoneId.systemDefault()

        assessmentQueue = ArrayDeque(
            p.practicedWordIds.filter { Progression.canAttemptAssessment(p, it, now, zone) }.sorted()
        )
        // Due flashcards: a review state past due, or a practiced word never reviewed.
        val reviewed = p.reviewStates.associateBy { it.wordId }
        flashcardQueue = ArrayDeque(
            p.practicedWordIds.filter { id ->
                val r = reviewed[id]
                r == null || !r.dueDate.isAfter(now)
            }.sorted()
        )
        _state.value = UiState(
            loading = false,
            mode = _state.value.mode,
            assessmentRemaining = assessmentQueue.size,
            flashcardsRemaining = flashcardQueue.size,
        )
        advance()
    }

    fun setMode(mode: Mode) {
        _state.update { it.copy(mode = mode, lastAnswerCorrect = null, flashcardRevealed = false) }
        viewModelScope.launch { advance() }
    }

    private suspend fun advance() {
        when (_state.value.mode) {
            Mode.ASSESSMENT -> {
                val id = assessmentQueue.firstOrNull()
                val word = id?.let { words.word(it) }
                _state.update {
                    it.copy(
                        question = word?.let { w -> buildQuestion(w) },
                        lastAnswerCorrect = null,
                        assessmentRemaining = assessmentQueue.size,
                    )
                }
            }
            Mode.FLASHCARDS -> {
                val id = flashcardQueue.firstOrNull()
                _state.update {
                    it.copy(
                        flashcard = id?.let { fid -> words.word(fid) },
                        flashcardRevealed = false,
                        flashcardsRemaining = flashcardQueue.size,
                    )
                }
            }
        }
    }

    private suspend fun buildQuestion(word: Word): Question {
        val pool = words.allWords()
        val distractors = AssessmentDistractors.distractors(word, pool, seed)
        val options = (distractors + word.shortDefinition).let { opts ->
            // stable per-word ordering so options don't reshuffle on recompose
            opts.sortedBy { com.stackspeak.domain.stableHash(word.id + it).toString() }
        }
        return Question(word, options, word.shortDefinition)
    }

    fun answer(option: String) = viewModelScope.launch {
        val q = _state.value.question ?: return@launch
        val correct = option == q.correct
        progress.recordAssessment(q.word.id, correct, option, q.correct)
        _state.update { it.copy(lastAnswerCorrect = correct) }
    }

    fun nextQuestion() = viewModelScope.launch {
        assessmentQueue.removeFirstOrNull()
        advance()
    }

    fun reveal() = _state.update { it.copy(flashcardRevealed = true) }

    fun grade(quality: Int) = viewModelScope.launch {
        val card = _state.value.flashcard ?: return@launch
        progress.gradeReview(card.id, quality)
        flashcardQueue.removeFirstOrNull()
        advance()
    }
}
