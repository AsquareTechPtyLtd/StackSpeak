package com.stackspeak.features.books

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.stackspeak.data.content.ComparisonColumn
import com.stackspeak.data.content.ContentBlock
import com.stackspeak.data.content.InlineMark
import com.stackspeak.data.content.InlineRun
import com.stackspeak.designsystem.JetBrainsMono
import com.stackspeak.designsystem.LocalStackSpeakColors
import com.stackspeak.designsystem.StackSpeakColors
import com.stackspeak.designsystem.StackSpeakTypography

/** Renders a list of [ContentBlock]s — the book-card content renderer (ports iOS ContentBlockRenderer). */
@Composable
fun ContentBlocks(blocks: List<ContentBlock>, modifier: Modifier = Modifier) {
    val colors = LocalStackSpeakColors.current
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        blocks.forEach { Block(it, colors) }
    }
}

@Composable
private fun Block(block: ContentBlock, colors: StackSpeakColors) {
    when (block) {
        is ContentBlock.Paragraph ->
            Text(annotated(block.runs, colors), style = StackSpeakTypography.body, color = colors.ink)

        is ContentBlock.Heading ->
            Text(
                block.text,
                style = if (block.level <= 2) StackSpeakTypography.title3 else StackSpeakTypography.headline,
                color = colors.ink,
            )

        is ContentBlock.BulletList -> Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            block.items.forEachIndexed { i, runs ->
                Row {
                    Text(
                        if (block.ordered) "${i + 1}. " else "•  ",
                        style = StackSpeakTypography.body, color = colors.inkMuted,
                    )
                    Text(annotated(runs, colors), style = StackSpeakTypography.body, color = colors.ink)
                }
            }
        }

        is ContentBlock.Code -> Text(
            block.code,
            style = StackSpeakTypography.code,
            color = colors.codeInk,
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(colors.codeBg).padding(12.dp),
        )

        is ContentBlock.Callout -> {
            val tint = when (block.variant) {
                ContentBlock.Callout.Variant.WARNING -> colors.warn
                ContentBlock.Callout.Variant.TIP -> colors.good
                ContentBlock.Callout.Variant.INFO -> colors.accent
            }
            Text(
                annotated(block.runs, colors),
                style = StackSpeakTypography.callout,
                color = colors.ink,
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(colors.accentBg).padding(12.dp),
            )
            // tint reserved for a leading bar in a later polish pass
            @Suppress("UNUSED_EXPRESSION") tint
        }

        is ContentBlock.Image -> block.caption?.let {
            Text(it, style = StackSpeakTypography.footnote, fontStyle = FontStyle.Italic, color = colors.inkMuted)
        }

        is ContentBlock.Table -> Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            if (block.headers.isNotEmpty()) TableRow(block.headers, colors, header = true)
            block.rows.forEach { TableRow(it, colors, header = false) }
        }

        is ContentBlock.Comparison -> Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            ComparisonCol(block.left, colors, Modifier.weight(1f))
            ComparisonCol(block.right, colors, Modifier.weight(1f))
        }
    }
}

@Composable
private fun TableRow(cells: List<String>, colors: StackSpeakColors, header: Boolean) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        cells.forEach {
            Text(
                it,
                style = if (header) StackSpeakTypography.footnote else StackSpeakTypography.caption,
                color = if (header) colors.ink else colors.inkMuted,
                fontWeight = if (header) FontWeight.SemiBold else FontWeight.Normal,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun ComparisonCol(col: ComparisonColumn, colors: StackSpeakColors, modifier: Modifier) {
    Column(modifier.clip(RoundedCornerShape(8.dp)).background(colors.surfaceAlt).padding(10.dp)) {
        Text(col.label, style = StackSpeakTypography.footnote, color = colors.accent, fontWeight = FontWeight.SemiBold)
        Text(annotated(col.runs, colors), style = StackSpeakTypography.footnote, color = colors.ink)
    }
}

/** Builds an AnnotatedString from inline runs, applying bold/italic/code/link marks. */
private fun annotated(runs: List<InlineRun>, colors: StackSpeakColors): AnnotatedString = buildAnnotatedString {
    runs.forEach { run ->
        var style = SpanStyle()
        run.marks.forEach { mark ->
            style = when (mark) {
                InlineMark.BOLD -> style.copy(fontWeight = FontWeight.Bold)
                InlineMark.ITALIC -> style.copy(fontStyle = FontStyle.Italic)
                InlineMark.CODE -> style.copy(fontFamily = JetBrainsMono, background = colors.codeBg, color = colors.codeInk)
                InlineMark.LINK -> style.copy(color = colors.accent)
            }
        }
        withStyle(style) { append(run.text) }
    }
}
