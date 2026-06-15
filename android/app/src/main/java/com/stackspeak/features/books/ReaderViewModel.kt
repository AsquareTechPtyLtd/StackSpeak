package com.stackspeak.features.books

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.stackspeak.data.BookRepository
import com.stackspeak.data.ProgressRepository
import com.stackspeak.data.content.BookCard
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ReaderViewModel @Inject constructor(
    private val books: BookRepository,
    private val progress: ProgressRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val chapterTitle: String = "",
        val cards: List<BookCard> = emptyList(),
        val index: Int = 0,
    ) {
        val current: BookCard? get() = cards.getOrNull(index)
        val hasPrev: Boolean get() = index > 0
        val hasNext: Boolean get() = index < cards.size - 1
    }

    private val _state = MutableStateFlow(UiState())
    val state = _state.asStateFlow()
    private var bookId: String = ""

    fun load(bookId: String, chapterId: String) = viewModelScope.launch {
        this@ReaderViewModel.bookId = bookId
        val book = books.catalog().firstOrNull { it.id == bookId } ?: return@launch
        val manifest = books.manifest(book)
        val chapter = manifest.chapters.firstOrNull { it.id == chapterId } ?: return@launch
        val cards = books.cards(book, chapter)
        _state.value = UiState(loading = false, chapterTitle = chapter.title, cards = cards, index = 0)
        markCurrentRead()
    }

    fun next() {
        _state.update { if (it.hasNext) it.copy(index = it.index + 1) else it }
        markCurrentRead()
    }

    fun prev() = _state.update { if (it.hasPrev) it.copy(index = it.index - 1) else it }

    private fun markCurrentRead() {
        val card = _state.value.current ?: return
        viewModelScope.launch { progress.markBookCardRead(bookId, card.id) }
    }
}
