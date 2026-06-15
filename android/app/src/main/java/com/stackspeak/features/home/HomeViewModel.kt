package com.stackspeak.features.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.stackspeak.data.DailyRepository
import com.stackspeak.data.ProgressRepository
import com.stackspeak.data.WordRepository
import com.stackspeak.data.content.Word
import com.stackspeak.domain.Levels
import com.stackspeak.domain.Progression
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val words: WordRepository,
    private val progress: ProgressRepository,
    private val daily: DailyRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val words: List<Word> = emptyList(),
        val completedIds: Set<String> = emptySet(),
        val streak: Int = 0,
        val level: Int = 1,
        val levelTitle: String = "",
        val goal: Int = 5,
    ) {
        val doneCount: Int get() = words.count { it.id in completedIds }
    }

    private val _state = MutableStateFlow(UiState())
    val state = _state.asStateFlow()

    fun refresh() = viewModelScope.launch {
        val p = progress.ensureLoaded()
        val set = daily.todaysSet()
        _state.value = UiState(
            loading = false,
            words = words.wordsByIds(set.wordIds),
            completedIds = set.completedWordIds,
            streak = Progression.displayedStreak(p, Instant.now(), ZoneId.systemDefault()),
            level = p.level,
            levelTitle = Levels.definition(p.level)?.title ?: "",
            goal = p.dailyWordGoal ?: 5,
        )
    }

    fun isCompleted(wordId: String): Boolean = wordId in _state.value.completedIds
}
