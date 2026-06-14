package com.stackspeak.designsystem

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider

// Map the StackSpeak palette onto a Material3 ColorScheme so stock components
// (ripples, text fields, etc.) pick up brand colors. Bespoke UI should read
// LocalStackSpeakColors directly for the full token set.
private val LightMaterialScheme = lightColorScheme(
    primary = lightStackSpeakColors.accent,
    onPrimary = lightStackSpeakColors.accentText,
    background = lightStackSpeakColors.bg,
    onBackground = lightStackSpeakColors.ink,
    surface = lightStackSpeakColors.surface,
    onSurface = lightStackSpeakColors.ink,
    surfaceVariant = lightStackSpeakColors.surfaceAlt,
    onSurfaceVariant = lightStackSpeakColors.inkMuted,
    error = lightStackSpeakColors.bad,
    outline = lightStackSpeakColors.lineStrong,
)

private val DarkMaterialScheme = darkColorScheme(
    primary = darkStackSpeakColors.accent,
    onPrimary = darkStackSpeakColors.accentText,
    background = darkStackSpeakColors.bg,
    onBackground = darkStackSpeakColors.ink,
    surface = darkStackSpeakColors.surface,
    onSurface = darkStackSpeakColors.ink,
    surfaceVariant = darkStackSpeakColors.surfaceAlt,
    onSurfaceVariant = darkStackSpeakColors.inkMuted,
    error = darkStackSpeakColors.bad,
    outline = darkStackSpeakColors.lineStrong,
)

@Composable
fun StackSpeakTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colors = if (darkTheme) darkStackSpeakColors else lightStackSpeakColors
    val materialScheme = if (darkTheme) DarkMaterialScheme else LightMaterialScheme

    CompositionLocalProvider(LocalStackSpeakColors provides colors) {
        MaterialTheme(
            colorScheme = materialScheme,
            typography = StackSpeakMaterialTypography,
            content = content,
        )
    }
}
