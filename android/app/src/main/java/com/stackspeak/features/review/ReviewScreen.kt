package com.stackspeak.features.review

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.stackspeak.designsystem.LocalStackSpeakColors
import com.stackspeak.designsystem.StackSpeakTypography

@Composable
fun ReviewScreen(viewModel: ReviewViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val colors = LocalStackSpeakColors.current

    LaunchedEffect(Unit) { viewModel.load() }

    Column(Modifier.fillMaxSize().padding(20.dp)) {
        Text("Review", style = StackSpeakTypography.title1Serif, color = colors.ink)
        Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            ModeChip("Assessment (${state.assessmentRemaining})", state.mode == ReviewViewModel.Mode.ASSESSMENT, Modifier.weight(1f)) {
                viewModel.setMode(ReviewViewModel.Mode.ASSESSMENT)
            }
            ModeChip("Flashcards (${state.flashcardsRemaining})", state.mode == ReviewViewModel.Mode.FLASHCARDS, Modifier.weight(1f)) {
                viewModel.setMode(ReviewViewModel.Mode.FLASHCARDS)
            }
        }

        when (state.mode) {
            ReviewViewModel.Mode.ASSESSMENT -> Assessment(state, viewModel)
            ReviewViewModel.Mode.FLASHCARDS -> Flashcards(state, viewModel)
        }
    }
}

@Composable
private fun Assessment(state: ReviewViewModel.UiState, vm: ReviewViewModel) {
    val colors = LocalStackSpeakColors.current
    val q = state.question
    if (q == null) {
        EmptyState("All caught up — practice more words on Today to unlock assessments.")
        return
    }
    Text("What does this mean?", style = StackSpeakTypography.callout, color = colors.inkMuted)
    Text(q.word.word, style = StackSpeakTypography.title2, color = colors.ink, modifier = Modifier.padding(vertical = 12.dp))

    q.options.forEach { option ->
        val answered = state.lastAnswerCorrect != null
        val isCorrectOption = option == q.correct
        val bg = when {
            !answered -> colors.surface
            isCorrectOption -> colors.good
            else -> colors.surfaceAlt
        }
        Text(
            option,
            style = StackSpeakTypography.body,
            color = if (answered && isCorrectOption) colors.accentText else colors.ink,
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 4.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(bg)
                .clickable(enabled = !answered) { vm.answer(option) }
                .padding(14.dp),
        )
    }

    if (state.lastAnswerCorrect != null) {
        Text(
            if (state.lastAnswerCorrect == true) "Correct!" else "Not quite — try again tomorrow.",
            style = StackSpeakTypography.headline,
            color = if (state.lastAnswerCorrect == true) colors.good else colors.warn,
            modifier = Modifier.padding(top = 12.dp),
        )
        Button(
            onClick = { vm.nextQuestion() },
            colors = ButtonDefaults.buttonColors(containerColor = colors.accent, contentColor = colors.accentText),
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
        ) { Text("Continue") }
    }
}

@Composable
private fun Flashcards(state: ReviewViewModel.UiState, vm: ReviewViewModel) {
    val colors = LocalStackSpeakColors.current
    val card = state.flashcard
    if (card == null) {
        EmptyState("No cards due. Practiced words appear here for spaced review.")
        return
    }
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(colors.surface).padding(20.dp),
    ) {
        Text(card.word, style = StackSpeakTypography.title2, color = colors.ink)
        if (state.flashcardRevealed) {
            Text(card.shortDefinition, style = StackSpeakTypography.body, color = colors.inkMuted, modifier = Modifier.padding(top = 12.dp))
        }
    }
    if (!state.flashcardRevealed) {
        Button(
            onClick = { vm.reveal() },
            colors = ButtonDefaults.buttonColors(containerColor = colors.accent, contentColor = colors.accentText),
            modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
        ) { Text("Reveal") }
    } else {
        Row(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GradeButton("Again", colors.bad, Modifier.weight(1f)) { vm.grade(2) }
            GradeButton("Good", colors.accent, Modifier.weight(1f)) { vm.grade(4) }
            GradeButton("Easy", colors.good, Modifier.weight(1f)) { vm.grade(5) }
        }
    }
}

@Composable
private fun EmptyState(message: String) {
    val colors = LocalStackSpeakColors.current
    Text(message, style = StackSpeakTypography.callout, color = colors.inkMuted, modifier = Modifier.padding(top = 24.dp))
}

@Composable
private fun ModeChip(text: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val colors = LocalStackSpeakColors.current
    Text(
        text, style = StackSpeakTypography.footnote, textAlign = TextAlign.Center,
        color = if (selected) colors.accent else colors.inkMuted,
        modifier = modifier.clip(RoundedCornerShape(8.dp))
            .background(if (selected) colors.accentBg else colors.surface)
            .clickable(onClick = onClick).padding(vertical = 10.dp),
    )
}

@Composable
private fun GradeButton(text: String, color: androidx.compose.ui.graphics.Color, modifier: Modifier, onClick: () -> Unit) {
    val colors = LocalStackSpeakColors.current
    Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(containerColor = color, contentColor = colors.accentText),
        modifier = modifier,
    ) { Text(text, style = StackSpeakTypography.footnote) }
}
