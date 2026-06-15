package com.stackspeak.data

import com.stackspeak.data.content.AssetReader
import com.stackspeak.data.content.BookCatalogLoader
import com.stackspeak.data.content.BookSummary
import com.stackspeak.data.content.StackCatalogLoader
import com.stackspeak.data.content.StackInfo
import com.stackspeak.data.content.Word
import com.stackspeak.data.content.WordCatalogLoader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/** In-memory bundled-content catalog, lazily loaded from assets once. */
@Singleton
class WordRepository @Inject constructor(private val assets: AssetReader) {
    private val mutex = Mutex()
    private var words: List<Word>? = null
    private var books: List<BookSummary>? = null

    suspend fun allWords(): List<Word> = mutex.withLock {
        words ?: withContext(Dispatchers.IO) { WordCatalogLoader.load(assets::read) }.also { words = it }
    }

    suspend fun wordsByIds(ids: List<String>): List<Word> {
        val byId = allWords().associateBy { it.id }
        return ids.mapNotNull { byId[it] }
    }

    suspend fun word(id: String): Word? = allWords().firstOrNull { it.id == id }

    suspend fun allBooks(): List<BookSummary> = mutex.withLock {
        books ?: withContext(Dispatchers.IO) { BookCatalogLoader.load(assets::read) }.also { books = it }
    }

    suspend fun stacks(): List<StackInfo> =
        withContext(Dispatchers.IO) { StackCatalogLoader.load(assets::read) }
}
