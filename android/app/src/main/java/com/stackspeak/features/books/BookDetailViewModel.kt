package com.stackspeak.features.books

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.stackspeak.data.BookRepository
import com.stackspeak.data.ProgressRepository
import com.stackspeak.data.content.BookManifest
import com.stackspeak.data.content.BookSummary
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class BookDetailViewModel @Inject constructor(
    private val books: BookRepository,
    private val progress: ProgressRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val book: BookSummary? = null,
        val manifest: BookManifest? = null,
        val completedCardIds: Set<String> = emptySet(),
    )

    private val _state = MutableStateFlow(UiState())
    val state = _state.asStateFlow()

    fun load(bookId: String) = viewModelScope.launch {
        val book = books.catalog().firstOrNull { it.id == bookId } ?: return@launch
        val manifest = books.manifest(book)
        val completed = progress.bookProgress(bookId)?.completedCardIds?.toSet() ?: emptySet()
        _state.value = UiState(loading = false, book = book, manifest = manifest, completedCardIds = completed)
    }
}
