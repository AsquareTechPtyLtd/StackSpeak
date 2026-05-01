import Testing
import Foundation

/// WCAG 2.2 contrast assertions for body-text token pairs in both modes.
/// Per the council's follow-up action #3 — codifies the 4.5:1 floor for
/// body-size text and 3:1 for large text / UI controls so a future token
/// edit that drops below threshold fails CI.
///
/// Token hex values are mirrored from `DesignSystem/Tokens.swift`; if a
/// token is updated there, the corresponding constant here must be updated
/// or the test will catch the regression.
@Suite("Token contrast — WCAG 2.2 floors")
struct TokenContrastTests {

    // MARK: - Light mode tokens (mirror Tokens.swift static let light)

    static let lightBg          = "F6F5F2"
    static let lightSurface     = "FFFFFF"
    static let lightInk         = "15161A"
    static let lightInkMuted    = "5B5E66"
    static let lightInkFaint    = "6E7079"
    static let lightAccent      = "3E4BDB"
    static let lightAccentText  = "FFFFFF"  // .white
    static let lightWarn        = "A85812"
    static let lightGood        = "2F6F47"
    static let lightStreak      = "E08A1E"
    static let lightStreakInk   = "15161A"

    // MARK: - Dark mode tokens

    static let darkBg          = "0B0C0E"
    static let darkSurface     = "141519"
    static let darkInk         = "F2F2F4"
    static let darkInkMuted    = "A4A7B0"
    static let darkInkFaint    = "797C84"
    static let darkAccent      = "8B93FF"
    static let darkAccentText  = "0B0C0E"
    static let darkStreak      = "F2A65A"
    static let darkStreakInk   = "0B0C0E"

    // MARK: - Light-mode body text (≥4.5:1)

    @Test("Light: ink vs bg ≥ 4.5:1")
    func lightInkOnBg() {
        #expect(contrastRatio(Self.lightInk, Self.lightBg) >= 4.5)
    }

    @Test("Light: inkMuted vs bg ≥ 4.5:1")
    func lightInkMutedOnBg() {
        #expect(contrastRatio(Self.lightInkMuted, Self.lightBg) >= 4.5)
    }

    @Test("Light: inkFaint vs bg ≥ 4.5:1 (P0-06 regression guard)")
    func lightInkFaintOnBg() {
        #expect(contrastRatio(Self.lightInkFaint, Self.lightBg) >= 4.5)
    }

    @Test("Light: inkFaint vs surface ≥ 4.5:1")
    func lightInkFaintOnSurface() {
        #expect(contrastRatio(Self.lightInkFaint, Self.lightSurface) >= 4.5)
    }

    @Test("Light: warn vs bg ≥ 4.5:1 (P1-12 regression guard)")
    func lightWarnOnBg() {
        #expect(contrastRatio(Self.lightWarn, Self.lightBg) >= 4.5)
    }

    @Test("Light: good vs bg ≥ 4.5:1")
    func lightGoodOnBg() {
        #expect(contrastRatio(Self.lightGood, Self.lightBg) >= 4.5)
    }

    // MARK: - Light-mode UI controls (≥3:1)

    @Test("Light: accentText on accent ≥ 4.5:1")
    func lightAccentTextOnAccent() {
        #expect(contrastRatio(Self.lightAccentText, Self.lightAccent) >= 4.5)
    }

    @Test("Light: accentText on inkFaint (disabled CTA) ≥ 4.5:1 (P0-05 guard)")
    func lightDisabledCTA() {
        #expect(contrastRatio(Self.lightAccentText, Self.lightInkFaint) >= 4.5)
    }

    @Test("Light: streakInk on streak ≥ 3:1 (P0-14 guard)")
    func lightStreakInkOnStreak() {
        #expect(contrastRatio(Self.lightStreakInk, Self.lightStreak) >= 3.0)
    }

    // MARK: - Dark-mode body text (≥4.5:1)

    @Test("Dark: ink vs bg ≥ 4.5:1")
    func darkInkOnBg() {
        #expect(contrastRatio(Self.darkInk, Self.darkBg) >= 4.5)
    }

    @Test("Dark: inkMuted vs bg ≥ 4.5:1")
    func darkInkMutedOnBg() {
        #expect(contrastRatio(Self.darkInkMuted, Self.darkBg) >= 4.5)
    }

    @Test("Dark: inkFaint vs bg ≥ 4.5:1 (out-of-scope #1 guard)")
    func darkInkFaintOnBg() {
        #expect(contrastRatio(Self.darkInkFaint, Self.darkBg) >= 4.5)
    }

    @Test("Dark: inkFaint vs surface ≥ 4.5:1")
    func darkInkFaintOnSurface() {
        #expect(contrastRatio(Self.darkInkFaint, Self.darkSurface) >= 4.5)
    }

    // MARK: - Dark-mode UI controls

    @Test("Dark: accentText on accent ≥ 4.5:1")
    func darkAccentTextOnAccent() {
        #expect(contrastRatio(Self.darkAccentText, Self.darkAccent) >= 4.5)
    }

    @Test("Dark: accentText on inkFaint (disabled CTA) ≥ 4.5:1 (out-of-scope #2 guard)")
    func darkDisabledCTA() {
        #expect(contrastRatio(Self.darkAccentText, Self.darkInkFaint) >= 4.5)
    }

    @Test("Dark: streakInk on streak ≥ 3:1")
    func darkStreakInkOnStreak() {
        #expect(contrastRatio(Self.darkStreakInk, Self.darkStreak) >= 3.0)
    }
}

// MARK: - WCAG 2.2 contrast helpers (relative-luminance formula)

/// Relative luminance per WCAG 2.2: each sRGB channel converted to linear,
/// then weighted as 0.2126 R + 0.7152 G + 0.0722 B.
private func relativeLuminance(_ hex: String) -> Double {
    let (r, g, b) = sRGB(from: hex)
    func channel(_ c: Double) -> Double {
        c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
}

/// WCAG 2.2 contrast ratio between two sRGB hex colors. Always returns the
/// brighter-over-darker form (≥ 1.0).
func contrastRatio(_ a: String, _ b: String) -> Double {
    let la = relativeLuminance(a)
    let lb = relativeLuminance(b)
    let lighter = max(la, lb)
    let darker = min(la, lb)
    return (lighter + 0.05) / (darker + 0.05)
}

private func sRGB(from hex: String) -> (Double, Double, Double) {
    let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: trimmed).scanHexInt64(&int)
    let r = Double((int >> 16) & 0xFF) / 255
    let g = Double((int >>  8) & 0xFF) / 255
    let b = Double( int        & 0xFF) / 255
    return (r, g, b)
}
