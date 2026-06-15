package com.stackspeak.features.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.stackspeak.data.content.StackInfo
import com.stackspeak.designsystem.LocalStackSpeakColors
import com.stackspeak.designsystem.StackSpeakTypography

@Composable
fun OnboardingScreen(viewModel: OnboardingViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val colors = LocalStackSpeakColors.current

    Column(Modifier.fillMaxSize().padding(20.dp)) {
        Text("Choose your stacks", style = StackSpeakTypography.title1Serif, color = colors.ink)
        Text(
            "Pick at least 3. Five words a day from the domains you care about.",
            style = StackSpeakTypography.callout,
            color = colors.inkMuted,
            modifier = Modifier.padding(top = 8.dp, bottom = 16.dp),
        )

        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(state.stacks, key = { it.id }) { stack ->
                StackRow(stack, selected = stack.id in state.selected) { viewModel.toggle(stack.id) }
            }
        }

        Button(
            onClick = { viewModel.complete {} },
            enabled = state.canContinue,
            colors = ButtonDefaults.buttonColors(containerColor = colors.accent, contentColor = colors.accentText),
            modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
        ) {
            Text(if (state.canContinue) "Continue" else "Pick ${OnboardingViewModel.MIN_STACKS - state.selected.size} more")
        }
    }
}

@Composable
private fun StackRow(stack: StackInfo, selected: Boolean, onClick: () -> Unit) {
    val colors = LocalStackSpeakColors.current
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (selected) colors.accentBg else colors.surface)
            .clickable(onClick = onClick)
            .padding(14.dp),
    ) {
        Text(
            stack.name.ifBlank { stack.id },
            style = StackSpeakTypography.headline,
            color = if (selected) colors.accent else colors.ink,
            fontWeight = FontWeight.SemiBold,
        )
        if (stack.description.isNotBlank()) {
            Text(stack.description, style = StackSpeakTypography.footnote, color = colors.inkMuted)
        }
    }
}
