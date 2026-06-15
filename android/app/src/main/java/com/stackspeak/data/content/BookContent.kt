package com.stackspeak.data.content

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** Inline mark on a text run — ported from iOS `InlineMark`. */
enum class InlineMark { BOLD, ITALIC, CODE, LINK }

/** One slice of inline text; `marks` compose, `href` only meaningful with LINK. */
data class InlineRun(val text: String, val marks: List<InlineMark> = emptyList(), val href: String? = null)

/** One labelled column of a comparison block. */
data class ComparisonColumn(val label: String, val runs: List<InlineRun>)

/**
 * Structured book-card content — a tagged union keyed on `"type"`, ported from
 * iOS `ContentBlock`. Parsed manually (not via @Serializable polymorphism) so the
 * legacy aliases (`lang`/`content` for code, `ordered` list style) decode leniently.
 */
sealed interface ContentBlock {
    data class Paragraph(val runs: List<InlineRun>) : ContentBlock
    data class Heading(val level: Int, val text: String) : ContentBlock
    data class BulletList(val ordered: Boolean, val items: List<List<InlineRun>>) : ContentBlock
    data class Code(val language: String, val code: String) : ContentBlock
    data class Callout(val variant: Variant, val runs: List<InlineRun>) : ContentBlock {
        enum class Variant { INFO, TIP, WARNING }
    }
    data class Image(val asset: String, val caption: String?) : ContentBlock
    data class Table(val headers: List<String>, val rows: List<List<String>>) : ContentBlock
    data class Comparison(val left: ComparisonColumn, val right: ComparisonColumn) : ContentBlock
}

/** Tolerant parser for the on-disk content-block JSON (mirrors iOS's lenient decode). */
object ContentBlockParser {

    fun parseBlocks(array: JsonArray?): List<ContentBlock> =
        array?.mapNotNull { runCatching { parseBlock(it.jsonObject) }.getOrNull() } ?: emptyList()

    private fun parseBlock(o: JsonObject): ContentBlock? {
        return when (o["type"]?.jsonPrimitive?.contentOrNull) {
            "paragraph" -> ContentBlock.Paragraph(parseRuns(o["runs"]?.jsonArray))
            "heading" -> ContentBlock.Heading(o["level"]?.jsonPrimitive?.int ?: 2, o.str("text"))
            "list" -> ContentBlock.BulletList(
                ordered = o["style"]?.jsonPrimitive?.contentOrNull.let { it == "numbered" || it == "ordered" },
                items = (o["items"]?.jsonArray ?: JsonArray(emptyList())).map { parseRuns(it.jsonArray) },
            )
            "code" -> ContentBlock.Code(
                language = o.strOrNull("language") ?: o.strOrNull("lang") ?: "",
                code = o.strOrNull("code") ?: o.strOrNull("text") ?: o.strOrNull("content") ?: "",
            )
            "callout" -> ContentBlock.Callout(
                variant = when (o.strOrNull("variant")) {
                    "tip" -> ContentBlock.Callout.Variant.TIP
                    "warning" -> ContentBlock.Callout.Variant.WARNING
                    else -> ContentBlock.Callout.Variant.INFO
                },
                runs = parseRuns(o["runs"]?.jsonArray),
            )
            "image" -> ContentBlock.Image(o.str("asset"), o.strOrNull("caption"))
            "table" -> ContentBlock.Table(
                headers = (o["headers"]?.jsonArray ?: JsonArray(emptyList())).map { it.jsonPrimitive.content },
                rows = (o["rows"]?.jsonArray ?: JsonArray(emptyList())).map { row -> row.jsonArray.map { it.jsonPrimitive.content } },
            )
            "comparison" -> {
                val left = o["left"]?.jsonObject
                val right = o["right"]?.jsonObject
                if (left == null || right == null) null
                else ContentBlock.Comparison(parseColumn(left), parseColumn(right))
            }
            else -> null
        }
    }

    private fun parseColumn(o: JsonObject) = ComparisonColumn(o.str("label"), parseRuns(o["runs"]?.jsonArray))

    private fun parseRuns(array: JsonArray?): List<InlineRun> = array?.map { el ->
        val o = el.jsonObject
        InlineRun(
            text = o.str("text"),
            marks = o["marks"]?.jsonArray?.mapNotNull {
                when (it.jsonPrimitive.contentOrNull) {
                    "bold" -> InlineMark.BOLD
                    "italic" -> InlineMark.ITALIC
                    "code" -> InlineMark.CODE
                    "link" -> InlineMark.LINK
                    else -> null
                }
            } ?: emptyList(),
            href = o.strOrNull("href"),
        )
    } ?: emptyList()

    private fun JsonObject.str(key: String): String = this[key]?.jsonPrimitive?.contentOrNull ?: ""
    private fun JsonObject.strOrNull(key: String): String? = this[key]?.jsonPrimitive?.contentOrNull
}
