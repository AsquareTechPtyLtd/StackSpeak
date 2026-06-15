package com.stackspeak.data.content

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** A library book's catalog entry (loaded from assets/books-catalog.json).
 *  Chapter/card content is parsed on demand later (M4). */
data class BookSummary(
    val id: String,
    val title: String,
    val author: String?,
    val summary: String,
    val coverIcon: String,
    val accentHex: String,
    val tags: List<String>,
    val categories: List<String>,
    val chapterCount: Int,
    val cardCount: Int,
    val manifestPath: String,
    val freeForAll: Boolean,
)

@Serializable
private data class BookSummaryDto(
    val id: String,
    val title: String,
    val author: String? = null,
    val summary: String = "",
    val coverIcon: String = "book",
    val accentHex: String = "#3E4BDB",
    val tags: List<String> = emptyList(),
    val categories: List<String> = emptyList(),
    val chapterCount: Int = 0,
    val cardCount: Int = 0,
    val manifestPath: String = "",
    val freeForAll: Boolean = false,
)

@Serializable
private data class BooksCatalogDto(val books: List<BookSummaryDto> = emptyList())

/** Loads the books catalog from assets/books-catalog.json. */
object BookCatalogLoader {
    private val json = Json { ignoreUnknownKeys = true }

    fun load(readAsset: (String) -> String): List<BookSummary> =
        json.decodeFromString(BooksCatalogDto.serializer(), readAsset("books-catalog.json")).books.map {
            BookSummary(
                id = it.id, title = it.title, author = it.author, summary = it.summary,
                coverIcon = it.coverIcon, accentHex = it.accentHex, tags = it.tags,
                categories = it.categories, chapterCount = it.chapterCount, cardCount = it.cardCount,
                manifestPath = it.manifestPath, freeForAll = it.freeForAll,
            )
        }
}
