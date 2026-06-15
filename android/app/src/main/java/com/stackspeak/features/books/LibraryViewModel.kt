package com.stackspeak.features.books

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.stackspeak.data.BookRepository
import com.stackspeak.data.content.BookSummary
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class LibraryViewModel @Inject constructor(private val books: BookRepository) : ViewModel() {
    private val _books = MutableStateFlow<List<BookSummary>>(emptyList())
    val books_ = _books.asStateFlow()

    init {
        viewModelScope.launch { _books.value = books.catalog() }
    }
}
