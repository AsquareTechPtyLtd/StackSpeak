package com.stackspeak.data.content

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** M2: words + books load from the bundled assets, with iOS-matching ids. */
class ContentLoaderTest {

    // Resolve android/app/src/main/assets regardless of test working dir.
    private val assets: File = run {
        var dir: File? = File(System.getProperty("user.dir") ?: ".")
        while (dir != null && !File(dir, "app/src/main/assets").isDirectory && !File(dir, "src/main/assets").isDirectory) {
            dir = dir.parentFile
        }
        requireNotNull(dir) { "assets dir not found" }
        File(dir, if (File(dir, "src/main/assets").isDirectory) "src/main/assets" else "app/src/main/assets")
    }

    private val read: (String) -> String = { File(assets, it).readText() }
    private val uuidRegex = Regex("[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}")

    @Test
    fun wordsLoadFromAssets() {
        val words = WordCatalogLoader.load(read)
        assertTrue("catalog non-empty", words.size > 500)
        assertTrue("every id is an UPPERCASE UUID", words.all { uuidRegex.matches(it.id) })
        assertTrue("no duplicate ids", words.map { it.id }.toSet().size == words.size)
        assertTrue("every word has a stack", words.all { it.stack.isNotBlank() })
    }

    @Test
    fun mnemonicIdsMapToDeterministicUuid() {
        // Cross-check the canonical-id rule against the M1 primitive fixture vector.
        assertTrue(WordCatalogLoader.canonicalWordId("api-bas-0001-cache") == "0326034C-C2B5-4C98-36E2-AF1800358A56")
        // A real UUID string is just uppercased.
        assertTrue(WordCatalogLoader.canonicalWordId("d25e9feb-d525-f60b-7f32-a769c12862f7")
            == "D25E9FEB-D525-F60B-7F32-A769C12862F7")
    }

    @Test
    fun booksCatalogLoads() {
        val books = BookCatalogLoader.load(read)
        assertTrue("books non-empty", books.isNotEmpty())
        assertTrue("every book has title + manifest", books.all { it.title.isNotBlank() && it.manifestPath.isNotBlank() })
    }
}
