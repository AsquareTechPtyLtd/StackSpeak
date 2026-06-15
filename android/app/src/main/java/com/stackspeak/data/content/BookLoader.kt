package com.stackspeak.data.content

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** A book's manifest: metadata + ordered chapter list (ported from iOS BookManifest). */
data class BookManifest(
    val id: String,
    val title: String,
    val author: String?,
    val summary: String,
    val chapters: List<ChapterMeta>,
)

data class ChapterMeta(
    val id: String,
    val order: Int,
    val title: String,
    val summary: String,
    val cardCount: Int,
    val cardIds: List<String>,
    val shards: List<String>,
)

/** One book card: a teaser + structured explanation + Feynman analogy blocks. */
data class BookCard(
    val id: String,
    val order: Int,
    val title: String,
    val teaser: String,
    val explanation: List<ContentBlock>,
    val feynman: List<ContentBlock>,
)

/**
 * Loads book manifests + chapter cards from assets. `manifestPath` is the
 * catalog-provided path (e.g. "books/<id>/manifest.json"); shard paths in the
 * manifest are resolved relative to the book directory. Card content blocks are
 * parsed leniently via [ContentBlockParser].
 */
object BookLoader {
    private val json = Json { ignoreUnknownKeys = true }

    fun loadManifest(manifestPath: String, readAsset: (String) -> String): BookManifest {
        val o = json.parseToJsonElement(readAsset(manifestPath)).jsonObject
        return BookManifest(
            id = o.str("id"),
            title = o.str("title"),
            author = o["author"]?.jsonPrimitive?.contentOrNull,
            summary = o.str("summary"),
            chapters = (o["chapters"]?.jsonArray ?: return BookManifest(o.str("id"), o.str("title"), null, o.str("summary"), emptyList()))
                .map { it.jsonObject }
                .map { c ->
                    ChapterMeta(
                        id = c.str("id"),
                        order = c["order"]?.jsonPrimitive?.int ?: 0,
                        title = c.str("title"),
                        summary = c.str("summary"),
                        cardCount = c["cardCount"]?.jsonPrimitive?.int ?: 0,
                        cardIds = c["cardIds"]?.jsonArray?.map { it.jsonPrimitive.content } ?: emptyList(),
                        shards = c["shards"]?.jsonArray?.map { it.jsonPrimitive.content } ?: emptyList(),
                    )
                }
                .sortedBy { it.order },
        )
    }

    /** Loads (and concatenates) all cards for a chapter across its shard files. */
    fun loadChapterCards(manifestPath: String, chapter: ChapterMeta, readAsset: (String) -> String): List<BookCard> {
        val bookDir = manifestPath.substringBeforeLast('/')
        return chapter.shards.flatMap { shard ->
            val text = runCatching { readAsset("$bookDir/$shard") }.getOrNull() ?: return@flatMap emptyList()
            val cards = runCatching { json.parseToJsonElement(text).jsonObject["cards"]?.jsonArray }.getOrNull() ?: return@flatMap emptyList()
            cards.map { it.jsonObject }.map { c ->
                BookCard(
                    id = c.str("id"),
                    order = c["order"]?.jsonPrimitive?.int ?: 0,
                    title = c.str("title"),
                    teaser = c.str("teaser"),
                    explanation = ContentBlockParser.parseBlocks(c["explanation"]?.jsonArray),
                    feynman = ContentBlockParser.parseBlocks(c["feynman"]?.jsonArray),
                )
            }
        }.sortedBy { it.order }
    }

    private fun kotlinx.serialization.json.JsonObject.str(key: String): String =
        this[key]?.jsonPrimitive?.contentOrNull ?: ""
}
