package com.stackspeak.features.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.stackspeak.features.speech.SpeechService
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.stackspeak.designsystem.LocalStackSpeakColors
import com.stackspeak.designsystem.StackSpeakTypography

@Composable
fun PracticeScreen(wordId: String, onDone: () -> Unit, viewModel: PracticeViewModel = hiltViewModel()) {
    val word by viewModel.word.collectAsStateWithLifecycle()
    val colors = LocalStackSpeakColors.current
    var explanation by remember { mutableStateOf("") }

    val context = LocalContext.current
    val speech = remember { SpeechService(context) }
    DisposableEffect(Unit) { onDispose { speech.destroy() } }
    fun listen() = speech.start(
        onResult = { explanation = (explanation.trim() + " " + it).trim() },
        onError = { },
    )
    val micPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) listen()
    }

    LaunchedEffectOnce(wordId) { viewModel.load(wordId) }

    Column(Modifier.fillMaxSize().padding(20.dp).verticalScroll(rememberScrollState())) {
        TextButton(onClick = onDone) { Text("‹ Back", color = colors.accent) }
        val w = word
        if (w == null) {
            Text("Loading…", style = StackSpeakTypography.body, color = colors.inkMuted)
        } else {
            Text(w.word, style = StackSpeakTypography.cardTitleSerif, color = colors.ink, modifier = Modifier.padding(top = 8.dp))
            if (w.pronunciation.isNotBlank()) {
                Text(w.pronunciation, style = StackSpeakTypography.callout, color = colors.inkFaint)
            }
            Text(
                w.simpleDefinition.ifBlank { w.shortDefinition },
                style = StackSpeakTypography.body, color = colors.ink,
                modifier = Modifier.padding(top = 16.dp),
            )
            if (w.techContext.isNotBlank()) {
                Text(w.techContext, style = StackSpeakTypography.callout, color = colors.inkMuted, modifier = Modifier.padding(top = 12.dp))
            }

            Text("Your turn — explain it simply", style = StackSpeakTypography.headline, color = colors.ink, modifier = Modifier.padding(top = 24.dp, bottom = 8.dp))
            BasicTextField(
                value = explanation,
                onValueChange = { explanation = it },
                textStyle = TextStyle(color = colors.ink, fontSize = StackSpeakTypography.body.fontSize),
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 120.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(colors.surfaceAlt)
                    .padding(12.dp),
            )

            if (speech.isAvailable) {
                TextButton(
                    onClick = { micPermission.launch(android.Manifest.permission.RECORD_AUDIO) },
                    modifier = Modifier.semantics { contentDescription = "Speak your explanation" },
                ) { Text("🎤  Speak instead", color = colors.accent) }
            }

            Button(
                onClick = { viewModel.submit(explanation, onDone) },
                enabled = explanation.trim().length >= 2,
                colors = ButtonDefaults.buttonColors(containerColor = colors.accent, contentColor = colors.accentText),
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            ) {
                Text("Lock it in")
            }
        }
    }
}

/** LaunchedEffect that runs once per key — small helper to trigger the load. */
@Composable
private fun LaunchedEffectOnce(key: Any, block: () -> Unit) {
    androidx.compose.runtime.LaunchedEffect(key) { block() }
}
