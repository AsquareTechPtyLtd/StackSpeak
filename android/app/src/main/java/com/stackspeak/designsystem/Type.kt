package com.stackspeak.designsystem

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.stackspeak.R

// Brand font families — same three faces as iOS (Inter / JetBrains Mono /
// Instrument Serif). TTFs live in res/font with Android-safe names.
val Inter = FontFamily(
    Font(R.font.inter_regular, FontWeight.Normal),
    Font(R.font.inter_medium, FontWeight.Medium),
    Font(R.font.inter_semibold, FontWeight.SemiBold),
    Font(R.font.inter_bold, FontWeight.Bold),
)

val JetBrainsMono = FontFamily(
    Font(R.font.jetbrainsmono_regular, FontWeight.Normal),
    Font(R.font.jetbrainsmono_medium, FontWeight.Medium),
    Font(R.font.jetbrainsmono_semibold, FontWeight.SemiBold),
)

val InstrumentSerif = FontFamily(
    Font(R.font.instrumentserif_italic, FontWeight.Normal, FontStyle.Italic),
)

/**
 * Semantic type tokens, mirroring iOS `TypographyTokens`
 * (ios/StackSpeak/DesignSystem/Tokens.swift) — same sizes/weights/faces.
 */
object StackSpeakTypography {
    val largeTitle = TextStyle(fontFamily = Inter, fontWeight = FontWeight.Bold, fontSize = 34.sp)
    val title1 = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 28.sp)
    val title2 = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 22.sp)
    val title3 = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 20.sp)
    val headline = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
    val body = TextStyle(fontFamily = Inter, fontWeight = FontWeight.Normal, fontSize = 17.sp)
    val callout = TextStyle(fontFamily = Inter, fontWeight = FontWeight.Normal, fontSize = 16.sp)
    val subheadline = TextStyle(fontFamily = Inter, fontWeight = FontWeight.Normal, fontSize = 15.sp)
    val footnote = TextStyle(fontFamily = Inter, fontWeight = FontWeight.Normal, fontSize = 13.sp)
    val caption = TextStyle(fontFamily = Inter, fontWeight = FontWeight.Normal, fontSize = 12.sp)

    val code = TextStyle(fontFamily = JetBrainsMono, fontWeight = FontWeight.Normal, fontSize = 14.sp)
    val codeLarge = TextStyle(fontFamily = JetBrainsMono, fontWeight = FontWeight.Normal, fontSize = 16.sp)
    val mono = TextStyle(fontFamily = JetBrainsMono, fontWeight = FontWeight.Medium, fontSize = 13.sp)

    val etymology = TextStyle(fontFamily = InstrumentSerif, fontStyle = FontStyle.Italic, fontSize = 17.sp)
    val etymologyLarge = TextStyle(fontFamily = InstrumentSerif, fontStyle = FontStyle.Italic, fontSize = 22.sp)
    val title1Serif = TextStyle(fontFamily = InstrumentSerif, fontStyle = FontStyle.Italic, fontSize = 34.sp)
    val cardTitleSerif = TextStyle(fontFamily = InstrumentSerif, fontStyle = FontStyle.Italic, fontSize = 32.sp)
}

/** Material3 Typography wiring so stock components inherit the brand font. */
val StackSpeakMaterialTypography = Typography(
    displayLarge = StackSpeakTypography.largeTitle,
    headlineLarge = StackSpeakTypography.title1,
    headlineMedium = StackSpeakTypography.title2,
    headlineSmall = StackSpeakTypography.title3,
    titleLarge = StackSpeakTypography.headline,
    bodyLarge = StackSpeakTypography.body,
    bodyMedium = StackSpeakTypography.callout,
    bodySmall = StackSpeakTypography.subheadline,
    labelLarge = StackSpeakTypography.headline,
    labelMedium = StackSpeakTypography.footnote,
    labelSmall = StackSpeakTypography.caption,
)
