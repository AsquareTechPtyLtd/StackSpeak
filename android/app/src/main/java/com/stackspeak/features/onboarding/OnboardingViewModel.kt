package com.stackspeak.features.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.stackspeak.data.ProgressRepository
import com.stackspeak.data.WordRepository
import com.stackspeak.data.content.StackInfo
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val words: WordRepository,
    private val progress: ProgressRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val stacks: List<StackInfo> = emptyList(),
        val selected: Set<String> = emptySet(),
    ) {
        val canContinue: Boolean get() = selected.size >= MIN_STACKS
    }

    private val _state = MutableStateFlow(UiState())
    val state = _state.asStateFlow()

    init {
        viewModelScope.launch {
            val available = words.stacks().filter { it.minimumLevel <= 1 }
            val preselected = available.filter { it.isMandatory }.map { it.id }.toSet()
                .ifEmpty { available.take(MIN_STACKS).map { it.id }.toSet() }
            _state.value = UiState(loading = false, stacks = available, selected = preselected)
        }
    }

    fun toggle(id: String) = _state.update {
        it.copy(selected = if (id in it.selected) it.selected - id else it.selected + id)
    }

    fun complete(onDone: () -> Unit) = viewModelScope.launch {
        progress.completeOnboarding(_state.value.selected)
        onDone()
    }

    companion object {
        const val MIN_STACKS = 3
    }
}
