package com.stackspeak.features.books

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.stackspeak.designsystem.LocalStackSpeakColors
import com.stackspeak.designsystem.StackSpeakTypography

@Composable
fun ReaderScreen(
    bookId: String,
    chapterId: String,
    onBack: () -> Unit,
    viewModel: ReaderViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val colors = LocalStackSpeakColors.current

    LaunchedEffect(bookId, chapterId) { viewModel.load(bookId, chapterId) }

    Column(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
        TextButton(onClick = onBack) { Text("‹ Chapters", color = colors.accent) }
        val card = state.current
        if (card == null) {
            Text(if (state.loading) "Loading…" else "No cards.", style = StackSpeakTypography.body, color = colors.inkMuted)
        } else {
            Text("${state.chapterTitle} · ${state.index + 1}/${state.cards.size}", style = StackSpeakTypography.caption, color = colors.inkFaint)
            Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState())) {
                Text(card.title, style = StackSpeakTypography.title3, color = colors.ink, modifier = Modifier.padding(top = 8.dp, bottom = 4.dp))
                if (card.teaser.isNotBlank()) {
                    Text(card.teaser, style = StackSpeakTypography.callout, color = colors.inkMuted, modifier = Modifier.padding(bottom = 12.dp))
                }
                ContentBlocks(card.explanation)
                if (card.feynman.isNotEmpty()) {
                    Text("In plain terms", style = StackSpeakTypography.headline, color = colors.accent, modifier = Modifier.padding(top = 20.dp, bottom = 8.dp))
                    ContentBlocks(card.feynman)
                }
            }
            Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (state.hasPrev) {
                    Button(
                        onClick = { viewModel.prev() },
                        colors = ButtonDefaults.buttonColors(containerColor = colors.surfaceAlt, contentColor = colors.ink),
                        modifier = Modifier.weight(1f),
                    ) { Text("Previous") }
                }
                Button(
                    onClick = { if (state.hasNext) viewModel.next() else onBack() },
                    colors = ButtonDefaults.buttonColors(containerColor = colors.accent, contentColor = colors.accentText),
                    modifier = Modifier.weight(1f),
                ) { Text(if (state.hasNext) "Next" else "Finish chapter") }
            }
        }
    }
}
