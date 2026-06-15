package com.stackspeak.features.books

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.stackspeak.data.content.ChapterMeta
import com.stackspeak.designsystem.LocalStackSpeakColors
import com.stackspeak.designsystem.StackSpeakTypography

@Composable
fun BookDetailScreen(
    bookId: String,
    onOpenChapter: (String) -> Unit,
    onBack: () -> Unit,
    viewModel: BookDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val colors = LocalStackSpeakColors.current

    LaunchedEffect(bookId) { viewModel.load(bookId) }

    Column(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
        TextButton(onClick = onBack) { Text("‹ Library", color = colors.accent) }
        Text(state.book?.title ?: "", style = StackSpeakTypography.title2, color = colors.ink)
        state.book?.summary?.let { Text(it, style = StackSpeakTypography.footnote, color = colors.inkMuted, modifier = Modifier.padding(vertical = 8.dp)) }

        Text("Chapters", style = StackSpeakTypography.headline, color = colors.ink, modifier = Modifier.padding(top = 8.dp, bottom = 8.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxSize()) {
            items(state.manifest?.chapters ?: emptyList(), key = { it.id }) { chapter ->
                ChapterRow(chapter, completed = state.completedCardIds) { onOpenChapter(chapter.id) }
            }
        }
    }
}

@Composable
private fun ChapterRow(chapter: ChapterMeta, completed: Set<String>, onClick: () -> Unit) {
    val colors = LocalStackSpeakColors.current
    val done = chapter.cardIds.count { it in completed }
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(colors.surface).clickable(onClick = onClick).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(Modifier.padding(end = 12.dp)) {
            Text("${chapter.order}. ${chapter.title}", style = StackSpeakTypography.body, color = colors.ink)
            if (chapter.summary.isNotBlank()) {
                Text(chapter.summary, style = StackSpeakTypography.caption, color = colors.inkMuted, maxLines = 2)
            }
        }
        Text("$done/${chapter.cardCount}", style = StackSpeakTypography.mono, color = if (done == chapter.cardCount && done > 0) colors.good else colors.inkMuted)
    }
}
