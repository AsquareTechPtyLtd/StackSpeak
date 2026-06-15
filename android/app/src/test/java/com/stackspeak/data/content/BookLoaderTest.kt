package com.stackspeak.data.content

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** M4: books + their chapters/cards/content-blocks load from the bundled assets. */
class BookLoaderTest {

    private val assets: File = run {
        var dir: File? = File(System.getProperty("user.dir") ?: ".")
        while (dir != null && !File(dir, "app/src/main/assets").isDirectory && !File(dir, "src/main/assets").isDirectory) {
            dir = dir.parentFile
        }
        requireNotNull(dir)
        File(dir, if (File(dir, "src/main/assets").isDirectory) "src/main/assets" else "app/src/main/assets")
    }
    private val read: (String) -> String = { File(assets, it).readText() }

    @Test
    fun manifestAndCardsLoadWithParsedContent() {
        val catalog = BookCatalogLoader.load(read)
        assertTrue("catalog non-empty", catalog.isNotEmpty())

        val book = catalog.first()
        val manifest = BookLoader.loadManifest(book.manifestPath, read)
        assertTrue("book has chapters", manifest.chapters.isNotEmpty())
        assertTrue("chapters are ordered", manifest.chapters.map { it.order } == manifest.chapters.map { it.order }.sorted())

        val firstChapter = manifest.chapters.first()
        val cards = BookLoader.loadChapterCards(book.manifestPath, firstChapter, read)
        assertTrue("chapter has cards", cards.isNotEmpty())

        val card = cards.first()
        assertTrue("card has a title", card.title.isNotBlank())
        assertTrue("card has parsed explanation blocks", card.explanation.isNotEmpty())
        assertTrue(
            "explanation has at least one paragraph with text",
            card.explanation.any { it is ContentBlock.Paragraph && it.runs.any { r -> r.text.isNotBlank() } },
        )
    }

    @Test
    fun parsesEveryBookCatalogEntry() {
        val catalog = BookCatalogLoader.load(read)
        // Every catalog book's manifest must load and expose at least one chapter.
        catalog.forEach { book ->
            val manifest = BookLoader.loadManifest(book.manifestPath, read)
            assertTrue("manifest ${book.id} has chapters", manifest.chapters.isNotEmpty())
        }
    }
}
