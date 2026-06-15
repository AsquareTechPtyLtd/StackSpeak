package com.stackspeak.data.content

import com.stackspeak.domain.deterministicUUID
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.util.UUID

/** A bundled vocabulary word (content, loaded from assets — not persisted in Room).
 *  Mirrors the selection-relevant + display fields of iOS `Word`. `id` is the
 *  UPPERCASE UUID (valid UUID string as-is, else derived via deterministicUUID). */
data class Word(
    val id: String,
    val word: String,
    val pronunciation: String,
    val partOfSpeech: String,
    val shortDefinition: String,
    val simpleDefinition: String,
    val longDefinition: String,
    val techContext: String,
    val professionalContext: String,
    val exampleSentence: String,
    val etymology: String,
    val connector: String,
    val codeExampleLanguage: String,
    val codeExampleCode: String,
    val backingBookId: String?,
    val backingChapterId: String?,
    val backingCardId: String?,
    val stack: String,
    val unlockLevel: Int,
    val tags: List<String>,
    val category: String,
)

// MARK: - Wire DTOs (match shared/stacks/*.json + words-index.json). Tolerant
// fields mirror iOS WordDTO's decodeIfPresent defaults.

@Serializable
private data class CodeExampleDto(val language: String? = null, val code: String? = null)

@Serializable
private data class BackingCardDto(val bookId: String, val chapterId: String? = null, val cardId: String? = null)

@Serializable
private data class WordDto(
    val id: String,
    val word: String,
    val pronunciation: String = "",
    val partOfSpeech: String = "",
    val shortDefinition: String = "",
    val simpleDefinition: String = "",
    val longDefinition: String = "",
    val techContext: String = "",
    val professionalContext: String = "",
    val exampleSentence: String = "",
    val etymology: String = "",
    val connector: String = "",
    val codeExample: CodeExampleDto? = null,
    val backingCard: BackingCardDto? = null,
    val unlockLevel: Int,
    val tags: List<String> = emptyList(),
    val category: String = "concepts",
)

@Serializable
private data class StackFileDto(val stack: String, val words: List<WordDto>)

@Serializable
private data class StackIndexEntryDto(val id: String, val file: String)

@Serializable
private data class StacksIndexDto(val stacks: List<StackIndexEntryDto>)

/**
 * Loads the bundled word catalog from assets. `readAsset` resolves a path
 * relative to the assets root (e.g. "words-index.json", "stacks/api-basic.json")
 * — injected so the loader is unit-testable without an AndroidManifest/AssetManager.
 * Mirrors iOS `WordService.loadWordsFromBundle`: skip undecodable stacks, dedupe
 * ids within the bundle, inject `stack` from the stack file.
 */
object WordCatalogLoader {
    private val json = Json { ignoreUnknownKeys = true }

    fun load(readAsset: (String) -> String): List<Word> {
        val index = json.decodeFromString(StacksIndexDto.serializer(), readAsset("words-index.json"))
        val out = ArrayList<Word>()
        val seen = HashSet<String>()
        for (entry in index.stacks) {
            val file = runCatching { readAsset(entry.file) }.getOrNull() ?: continue
            val stackFile = runCatching { json.decodeFromString(StackFileDto.serializer(), file) }.getOrNull() ?: continue
            for (dto in stackFile.words) {
                val id = canonicalWordId(dto.id)
                if (!seen.add(id)) continue
                out.add(dto.toWord(id, stackFile.stack))
            }
        }
        return out
    }

    /** Valid UUID → uppercased; mnemonic id → stable deterministic UUID (matches iOS). */
    fun canonicalWordId(raw: String): String =
        runCatching { UUID.fromString(raw).toString().uppercase() }.getOrElse { deterministicUUID(raw) }

    private fun WordDto.toWord(id: String, stack: String) = Word(
        id = id, word = word, pronunciation = pronunciation, partOfSpeech = partOfSpeech,
        shortDefinition = shortDefinition, simpleDefinition = simpleDefinition, longDefinition = longDefinition,
        techContext = techContext, professionalContext = professionalContext, exampleSentence = exampleSentence,
        etymology = etymology, connector = connector,
        codeExampleLanguage = codeExample?.language ?: "", codeExampleCode = codeExample?.code ?: "",
        backingBookId = backingCard?.bookId, backingChapterId = backingCard?.chapterId, backingCardId = backingCard?.cardId,
        stack = stack, unlockLevel = unlockLevel, tags = tags, category = category,
    )
}
