package com.stackspeak.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.stackspeak.designsystem.LocalStackSpeakColors
import com.stackspeak.designsystem.StackSpeakTheme
import com.stackspeak.designsystem.StackSpeakTypography
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            StackSpeakTheme {
                AppShell()
            }
        }
    }
}

/** M0 placeholder: an empty themed shell proving the design system renders. */
@Composable
private fun AppShell() {
    val colors = LocalStackSpeakColors.current
    Surface(modifier = Modifier.fillMaxSize(), color = colors.bg) {
        Box(modifier = Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
            Text(
                text = "StackSpeak",
                style = StackSpeakTypography.title1Serif,
                color = colors.ink
            )
        }
    }
}

@Preview(name = "Shell — Light", showBackground = true)
@Preview(name = "Shell — Dark", uiMode = android.content.res.Configuration.UI_MODE_NIGHT_YES, showBackground = true)
@Composable
private fun AppShellPreview() {
    StackSpeakTheme { AppShell() }
}
