package com.stackspeak.data

import com.stackspeak.data.content.AssetReader
import com.stackspeak.data.content.BookCard
import com.stackspeak.data.content.BookLoader
import com.stackspeak.data.content.BookManifest
import com.stackspeak.data.content.BookSummary
import com.stackspeak.data.content.ChapterMeta
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/** Loads book catalog/manifests/cards from assets (parsing off the main thread). */
@Singleton
class BookRepository @Inject constructor(
    private val words: WordRepository,
    private val assets: AssetReader,
) {
    suspend fun catalog(): List<BookSummary> = words.allBooks()

    suspend fun manifest(book: BookSummary): BookManifest =
        withContext(Dispatchers.IO) { BookLoader.loadManifest(book.manifestPath, assets::read) }

    suspend fun cards(book: BookSummary, chapter: ChapterMeta): List<BookCard> =
        withContext(Dispatchers.IO) { BookLoader.loadChapterCards(book.manifestPath, chapter, assets::read) }
}
