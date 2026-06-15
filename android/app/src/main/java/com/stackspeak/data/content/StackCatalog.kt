package com.stackspeak.data.content

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** A selectable stack (for onboarding / stack management). */
data class StackInfo(
    val id: String,
    val name: String,
    val description: String,
    val isMandatory: Boolean,
    val minimumLevel: Int,
)

@Serializable
private data class StackIndexMetaDto(
    val id: String,
    val name: String = "",
    val description: String = "",
    val isMandatory: Boolean = false,
    val minimumLevel: Int = 1,
)

@Serializable
private data class StacksIndexMetaDto(val stacks: List<StackIndexMetaDto>)

/** Loads stack metadata from words-index.json (names, mandatory flag, unlock level). */
object StackCatalogLoader {
    private val json = Json { ignoreUnknownKeys = true }

    fun load(readAsset: (String) -> String): List<StackInfo> =
        json.decodeFromString(StacksIndexMetaDto.serializer(), readAsset("words-index.json")).stacks.map {
            StackInfo(it.id, it.name, it.description, it.isMandatory, it.minimumLevel)
        }
}
