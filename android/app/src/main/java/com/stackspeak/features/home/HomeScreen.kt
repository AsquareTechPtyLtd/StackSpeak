package com.stackspeak.features.home

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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.stackspeak.data.content.Word
import com.stackspeak.designsystem.LocalStackSpeakColors
import com.stackspeak.designsystem.StackSpeakTypography

@Composable
fun HomeScreen(onOpenWord: (String) -> Unit, viewModel: HomeViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val colors = LocalStackSpeakColors.current

    // Refresh whenever the screen (re)enters composition — e.g. returning from practice.
    LaunchedEffect(Unit) { viewModel.refresh() }

    Column(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
        Row(
            Modifier.fillMaxWidth().padding(top = 20.dp, bottom = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column {
                Text("Today", style = StackSpeakTypography.title1Serif, color = colors.ink)
                Text(state.levelTitle, style = StackSpeakTypography.footnote, color = colors.inkMuted)
            }
            Column(horizontalAlignment = Alignment.End) {
                Text("🔥 ${state.streak}", style = StackSpeakTypography.headline, color = colors.streak)
                Text("${state.doneCount}/${state.words.size}", style = StackSpeakTypography.mono, color = colors.inkMuted)
            }
        }

        if (!state.loading && state.words.isEmpty()) {
            Text(
                "No words available — pick more stacks in onboarding.",
                style = StackSpeakTypography.callout, color = colors.inkMuted,
                modifier = Modifier.padding(top = 24.dp),
            )
        }

        LazyColumn(
            Modifier.fillMaxSize().padding(top = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(state.words, key = { it.id }) { word ->
                WordRow(word, completed = word.id in state.completedIds) { onOpenWord(word.id) }
            }
        }
    }
}

@Composable
private fun WordRow(word: Word, completed: Boolean, onClick: () -> Unit) {
    val colors = LocalStackSpeakColors.current
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(colors.surface)
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(Modifier.weight(1f)) {
            Text(word.word, style = StackSpeakTypography.headline, color = colors.ink)
            Text(word.shortDefinition, style = StackSpeakTypography.footnote, color = colors.inkMuted, maxLines = 2)
        }
        Text(if (completed) "✓" else "›", style = StackSpeakTypography.title3, color = if (completed) colors.good else colors.inkFaint)
    }
}
