import SwiftUI

struct ColorTokens {
    let bg: Color
    let surface: Color
    let surfaceAlt: Color
    let ink: Color
    let inkMuted: Color
    let inkFaint: Color
    let line: Color
    let lineStrong: Color
    let accent: Color
    let accentBg: Color
    let accentText: Color  // Text color on accent background (e.g., CTA buttons)
    /// Decorative tint for non-CTA accent usage — progress fills, status borders,
    /// active-state strokes. Same hue as `accent` today but kept separate so
    /// future visual tuning (e.g., dimming progress to favor CTA prominence)
    /// doesn't ripple into every primary action.
    let accentDecoration: Color
    let codeBg: Color
    let codeInk: Color
    let codeKey: Color
    let codeStr: Color
    let codeCom: Color
    let codeNum: Color
    let good: Color
    let warn: Color
    /// True-negative red for "Again" on flashcards and incorrect feedback.
    let bad: Color
    /// Warm orange for the streak flame — kept distinct from `accent` so the
    /// universal flame metaphor reads correctly.
    let streak: Color
    /// Near-black ink for icons/text drawn on top of `streak`. Fixed to a dark
    /// value in both modes because `streak` is a bright orange/amber in both.
    let streakInk: Color

    static let light = ColorTokens(
        bg: Color(hex: "F6F5F2"),
        surface: Color(hex: "FFFFFF"),
        surfaceAlt: Color(hex: "FBFAF7"),
        ink: Color(hex: "15161A"),
        inkMuted: Color(hex: "5B5E66"),
        inkFaint: Color(hex: "6E7079"),
        line: Color(hex: "14161C").opacity(0.08),
        lineStrong: Color(hex: "14161C").opacity(0.14),
        accent: Color(hex: "3E4BDB"),
        accentBg: Color(hex: "3E4BDB").opacity(0.08),
        accentText: .white,
        accentDecoration: Color(hex: "3E4BDB"),
        codeBg: Color(hex: "F2F1EC"),
        codeInk: Color(hex: "15161A"),
        codeKey: Color(hex: "8B2F7A"),
        codeStr: Color(hex: "2F6F47"),
        codeCom: Color(hex: "8A8A7F"),
        codeNum: Color(hex: "B5651D"),
        good: Color(hex: "2F6F47"),
        warn: Color(hex: "A85812"),
        bad: Color(hex: "C0392B"),
        streak: Color(hex: "E08A1E"),
        streakInk: Color(hex: "15161A")
    )

    static let dark = ColorTokens(
        bg: Color(hex: "0B0C0E"),
        surface: Color(hex: "141519"),
        surfaceAlt: Color(hex: "0F1013"),
        ink: Color(hex: "F2F2F4"),
        inkMuted: Color(hex: "A4A7B0"),
        inkFaint: Color(hex: "797C84"),
        line: Color(hex: "FFFFFF").opacity(0.06),
        lineStrong: Color(hex: "FFFFFF").opacity(0.12),
        accent: Color(hex: "8B93FF"),
        accentBg: Color(hex: "8B93FF").opacity(0.12),
        // Near-black for WCAG-safe contrast on the lighter dark-mode accent.
        accentText: Color(hex: "0B0C0E"),
        accentDecoration: Color(hex: "8B93FF"),
        codeBg: Color(hex: "0F1013"),
        codeInk: Color(hex: "E6E6EA"),
        codeKey: Color(hex: "D291E7"),
        codeStr: Color(hex: "7FCF99"),
        codeCom: Color(hex: "6B6E77"),
        codeNum: Color(hex: "E0A878"),
        good: Color(hex: "7FCF99"),
        warn: Color(hex: "E0A878"),
        bad: Color(hex: "FF6B6B"),
        streak: Color(hex: "F2A65A"),
        streakInk: Color(hex: "0B0C0E")
    )
}

struct SpacingTokens {
    let xs: CGFloat = 4
    let sm: CGFloat = 8
    let md: CGFloat = 12
    let lg: CGFloat = 16
    let xl: CGFloat = 20
    let xxl: CGFloat = 24
    let xxxl: CGFloat = 32

    /// One well-tuned card padding. Density preference removed (F10): a single
    /// considered default beats a personalization knob most users never touch.
    var cardPadding: EdgeInsets { EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20) }

    var cardGap: CGFloat { 12 }

    var rowPadding: CGFloat { 14 }
}

/// Three considered radii. Anything else is a smell.
enum RadiusTokens {
    /// Inline elements: chips, code blocks, small inputs.
    static let inline: CGFloat = 8
    /// Cards, buttons, sheets.
    static let card: CGFloat = 12
    /// Full pill — circles, capsules.
    static let pill: CGFloat = 999
}

/// Restrained motion language. Cross-fade for stage changes; spring only when a
/// physical metaphor genuinely applies.
enum MotionTokens {
    /// Default content swap (Feynman stage advance, panel reveals).
    static let standard: Animation = .easeInOut(duration: 0.18)
    /// Slightly snappier confirm (button press feedback, toggle).
    static let snappy: Animation = .easeOut(duration: 0.12)
    /// Reserved for celebration moments (level-up appear, streak tick).
    static let bounce: Animation = .spring(response: 0.45, dampingFraction: 0.65)
    /// Slow, repeating ambient nudge — used by SwipeNudge to suggest direction
    /// without commanding attention. 0.9s round-trip.
    static let nudge: Animation = .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
}

struct TypographyTokens {
    // MARK: - Font constructors with Dynamic Type scaling

    static func inter(size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Inter", size: size, relativeTo: textStyle).weight(weight)
    }

    static func jetBrainsMono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("JetBrainsMono-Regular", size: size, relativeTo: .caption)
    }

    static func instrumentSerif(size: CGFloat) -> Font {
        .custom("InstrumentSerif-Italic", size: size, relativeTo: .callout)
    }

    // MARK: - Semantic tokens

    static let largeTitle  = inter(size: 34, weight: .bold,     relativeTo: .largeTitle)
    static let title1      = inter(size: 28, weight: .semibold, relativeTo: .title)
    static let title2      = inter(size: 22, weight: .semibold, relativeTo: .title2)
    static let title3      = inter(size: 20, weight: .semibold, relativeTo: .title3)
    static let headline    = inter(size: 17, weight: .semibold, relativeTo: .headline)
    static let body        = inter(size: 17, weight: .regular,  relativeTo: .body)
    static let callout     = inter(size: 16, weight: .regular,  relativeTo: .callout)
    static let subheadline = inter(size: 15, weight: .regular,  relativeTo: .subheadline)
    static let footnote    = inter(size: 13, weight: .regular,  relativeTo: .footnote)
    static let caption     = inter(size: 12, weight: .regular,  relativeTo: .caption)

    static let code      = jetBrainsMono(size: 14)
    static let codeLarge = jetBrainsMono(size: 16)
    static let mono      = jetBrainsMono(size: 13, weight: .medium)

    static let etymology      = instrumentSerif(size: 17)
    static let etymologyLarge = instrumentSerif(size: 22)

    /// Single tuned card title size. Density removed (F10).
    static let cardTitle = inter(size: 26, weight: .semibold, relativeTo: .title)
}

// MARK: - Color hex initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            assert(false, "Invalid hex color string: \(hex)")
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - DEBUG font registration check

extension TypographyTokens {
    /// Call once at app launch in DEBUG builds to confirm all custom fonts loaded correctly.
    static func assertCustomFontsLoaded() {
#if DEBUG
        let required = ["Inter-Regular", "JetBrainsMono-Regular", "InstrumentSerif-Italic"]
        for name in required {
            assert(
                UIFont(name: name, size: 12) != nil,
                "Custom font '\(name)' not found. Ensure it is bundled under Resources/Fonts/ and declared in UIAppFonts."
            )
        }
#endif
    }
}
