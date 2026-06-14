import SwiftUI
import UIKit

// Trait-resolved palette for ColorTokens — split out per the
// <TypeName>+<Concern>.swift convention. Keeps the static light/dark literal
// tables in Tokens.swift and the per-trait resolution machinery here.
extension ColorTokens {
    /// Trait-resolved palette: every color picks its light/dark value from the
    /// rendering view's `UITraitCollection` at draw time, rather than eagerly
    /// choosing `.light`/`.dark` from a stored flag. This keeps a view's colors
    /// correct no matter which `ThemeManager` instance it binds to — SwiftUI can
    /// hand a scrolled/lazy cell the environment's *default* manager, and with an
    /// eager palette that cell renders the wrong mode (white cards in dark mode).
    /// Forced light/dark still works because the root sets `.preferredColorScheme`,
    /// which drives the trait collection these colors read.
    static let dynamic = ColorTokens(
        bg: dyn(\.bg), surface: dyn(\.surface), surfaceAlt: dyn(\.surfaceAlt),
        ink: dyn(\.ink), inkMuted: dyn(\.inkMuted), inkFaint: dyn(\.inkFaint),
        line: dyn(\.line), lineStrong: dyn(\.lineStrong),
        accent: dyn(\.accent), accentBg: dyn(\.accentBg), accentText: dyn(\.accentText),
        accentDecoration: dyn(\.accentDecoration),
        codeBg: dyn(\.codeBg), codeInk: dyn(\.codeInk), codeKey: dyn(\.codeKey),
        codeStr: dyn(\.codeStr), codeCom: dyn(\.codeCom), codeNum: dyn(\.codeNum),
        good: dyn(\.good), warn: dyn(\.warn), bad: dyn(\.bad),
        streak: dyn(\.streak), streakInk: dyn(\.streakInk), badInk: dyn(\.badInk)
    )

    /// Builds a dynamic `Color` that resolves `light`/`dark` per trait collection.
    private static func dyn(_ keyPath: KeyPath<ColorTokens, Color>) -> Color {
        Color(UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark[keyPath: keyPath]
                                                        : light[keyPath: keyPath])
        })
    }
}
