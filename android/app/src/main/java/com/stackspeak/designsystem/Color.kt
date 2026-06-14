package com.stackspeak.designsystem

import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/**
 * Full StackSpeak color token set, ported 1:1 from the iOS `ColorTokens`
 * (ios/StackSpeak/DesignSystem/Tokens.swift) — same names, same hex values, same
 * light/dark split. Consumed via [LocalStackSpeakColors]; never hardcode colors.
 * Opacity-based tokens (line/lineStrong/accentBg) are pre-baked as ARGB.
 */
data class StackSpeakColors(
    val bg: Color,
    val surface: Color,
    val surfaceAlt: Color,
    val ink: Color,
    val inkMuted: Color,
    val inkFaint: Color,
    val line: Color,
    val lineStrong: Color,
    val accent: Color,
    val accentBg: Color,
    val accentText: Color,
    val accentDecoration: Color,
    val codeBg: Color,
    val codeInk: Color,
    val codeKey: Color,
    val codeStr: Color,
    val codeCom: Color,
    val codeNum: Color,
    val good: Color,
    val warn: Color,
    val bad: Color,
    val streak: Color,
    val streakInk: Color,
    val badInk: Color,
    val isDark: Boolean,
)

val lightStackSpeakColors = StackSpeakColors(
    bg = Color(0xFFF6F5F2),
    surface = Color(0xFFFFFFFF),
    surfaceAlt = Color(0xFFFBFAF7),
    ink = Color(0xFF15161A),
    inkMuted = Color(0xFF5B5E66),
    inkFaint = Color(0xFF6E7079),
    line = Color(0x1414161C),       // 14161C @ 0.08
    lineStrong = Color(0x2414161C), // 14161C @ 0.14
    accent = Color(0xFF3E4BDB),
    accentBg = Color(0x143E4BDB),   // 3E4BDB @ 0.08
    accentText = Color(0xFFFFFFFF),
    accentDecoration = Color(0xFF3E4BDB),
    codeBg = Color(0xFFF2F1EC),
    codeInk = Color(0xFF15161A),
    codeKey = Color(0xFF8B2F7A),
    codeStr = Color(0xFF2F6F47),
    codeCom = Color(0xFF696960),
    codeNum = Color(0xFF964C10),
    good = Color(0xFF2F6F47),
    warn = Color(0xFFA85812),
    bad = Color(0xFFC0392B),
    streak = Color(0xFFB56A00),
    streakInk = Color(0xFF15161A),
    badInk = Color(0xFFFFFFFF),
    isDark = false,
)

val darkStackSpeakColors = StackSpeakColors(
    bg = Color(0xFF0B0C0E),
    surface = Color(0xFF141519),
    surfaceAlt = Color(0xFF0F1013),
    ink = Color(0xFFF2F2F4),
    inkMuted = Color(0xFFA4A7B0),
    inkFaint = Color(0xFF858891),
    line = Color(0x0FFFFFFF),       // FFFFFF @ 0.06
    lineStrong = Color(0x1FFFFFFF), // FFFFFF @ 0.12
    accent = Color(0xFF8B93FF),
    accentBg = Color(0x1F8B93FF),   // 8B93FF @ 0.12
    accentText = Color(0xFF0B0C0E),
    accentDecoration = Color(0xFF8B93FF),
    codeBg = Color(0xFF0F1013),
    codeInk = Color(0xFFE6E6EA),
    codeKey = Color(0xFFD291E7),
    codeStr = Color(0xFF7FCF99),
    codeCom = Color(0xFF84878F),
    codeNum = Color(0xFFE0A878),
    good = Color(0xFF7FCF99),
    warn = Color(0xFFE0A878),
    bad = Color(0xFFFF6B6B),
    streak = Color(0xFFF2A65A),
    streakInk = Color(0xFF0B0C0E),
    badInk = Color(0xFF0B0C0E),
    isDark = true,
)

/** Theme-resolved palette; provided by [StackSpeakTheme]. */
val LocalStackSpeakColors = staticCompositionLocalOf { lightStackSpeakColors }
