package com.stackspeak.features.practice

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.stackspeak.data.DailyRepository
import com.stackspeak.data.ProgressRepository
import com.stackspeak.data.WordRepository
import com.stackspeak.data.content.Word
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/** Drives the single-word practice (Feynman explain) screen. */
@HiltViewModel
class PracticeViewModel @Inject constructor(
    private val words: WordRepository,
    private val progress: ProgressRepository,
    private val daily: DailyRepository,
) : ViewModel() {

    private val _word = MutableStateFlow<Word?>(null)
    val word = _word.asStateFlow()

    fun load(wordId: String) = viewModelScope.launch { _word.value = words.word(wordId) }

    /** Saves the explanation, marks the word practiced + complete for today, then returns. */
    fun submit(explanation: String, onDone: () -> Unit) = viewModelScope.launch {
        val w = _word.value ?: return@launch onDone()
        progress.recordPractice(w.id, explanation.trim(), inputMethod = "text")
        daily.markCompleted(w.id)
        onDone()
    }
}
