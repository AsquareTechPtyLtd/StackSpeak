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
    let codeBg: Color
    let codeInk: Color
    let codeKey: Color
    let codeStr: Color
    let codeCom: Color
    let codeNum: Color
    let good: Color
    let warn: Color

    static let light = ColorTokens(
        bg: Color(hex: "F6F5F2"),
        surface: Color(hex: "FFFFFF"),
        surfaceAlt: Color(hex: "FBFAF7"),
        ink: Color(hex: "15161A"),
        inkMuted: Color(hex: "5B5E66"),
        inkFaint: Color(hex: "9A9CA3"),
        line: Color(hex: "14161C").opacity(0.08),
        lineStrong: Color(hex: "14161C").opacity(0.14),
        accent: Color(hex: "3E4BDB"),
        accentBg: Color(hex: "3E4BDB").opacity(0.08),
        codeBg: Color(hex: "F2F1EC"),
        codeInk: Color(hex: "15161A"),
        codeKey: Color(hex: "8B2F7A"),
        codeStr: Color(hex: "2F6F47"),
        codeCom: Color(hex: "8A8A7F"),
        codeNum: Color(hex: "B5651D"),
        good: Color(hex: "2F6F47"),
        warn: Color(hex: "B5651D")
    )

    static let dark = ColorTokens(
        bg: Color(hex: "0B0C0E"),
        surface: Color(hex: "141519"),
        surfaceAlt: Color(hex: "0F1013"),
        ink: Color(hex: "F2F2F4"),
        inkMuted: Color(hex: "A4A7B0"),
        inkFaint: Color(hex: "6B6E77"),
        line: Color.white.opacity(0.06),
        lineStrong: Color.white.opacity(0.12),
        accent: Color(hex: "8B93FF"),
        accentBg: Color(hex: "8B93FF").opacity(0.12),
        codeBg: Color(hex: "0F1013"),
        codeInk: Color(hex: "E6E6EA"),
        codeKey: Color(hex: "D291E7"),
        codeStr: Color(hex: "7FCF99"),
        codeCom: Color(hex: "6B6E77"),
        codeNum: Color(hex: "E0A878"),
        good: Color(hex: "7FCF99"),
        warn: Color(hex: "E0A878")
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

    func cardPadding(density: DensityPreference) -> EdgeInsets {
        switch density {
        case .compact:
            return EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
        case .roomy:
            return EdgeInsets(top: 22, leading: 22, bottom: 22, trailing: 22)
        }
    }

    func cardGap(density: DensityPreference) -> CGFloat {
        density == .compact ? 10 : 14
    }

    func rowPadding(density: DensityPreference) -> CGFloat {
        density == .compact ? 12 : 16
    }
}

struct TypographyTokens {
    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size).weight(weight)
    }

    static func jetBrainsMono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("JetBrainsMono", size: size).weight(weight)
    }

    static func instrumentSerif(size: CGFloat) -> Font {
        .custom("InstrumentSerif-Italic", size: size)
    }

    static let largeTitle = inter(size: 34, weight: .bold)
    static let title1 = inter(size: 28, weight: .semibold)
    static let title2 = inter(size: 22, weight: .semibold)
    static let title3 = inter(size: 20, weight: .semibold)
    static let headline = inter(size: 17, weight: .semibold)
    static let body = inter(size: 17, weight: .regular)
    static let callout = inter(size: 16, weight: .regular)
    static let subheadline = inter(size: 15, weight: .regular)
    static let footnote = inter(size: 13, weight: .regular)
    static let caption = inter(size: 12, weight: .regular)

    static let code = jetBrainsMono(size: 14, weight: .regular)
    static let codeLarge = jetBrainsMono(size: 16, weight: .regular)
    static let mono = jetBrainsMono(size: 13, weight: .medium)

    static let etymology = instrumentSerif(size: 15)
    static let etymologyLarge = instrumentSerif(size: 17)

    static func cardTitle(density: DensityPreference) -> Font {
        density == .compact ? inter(size: 22, weight: .semibold) : inter(size: 26, weight: .semibold)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
