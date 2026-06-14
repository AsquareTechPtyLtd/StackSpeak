import SwiftUI

@Observable
final class ThemeManager {
    var preference: ThemePreference = .system
    /// Set by the root view via `.onChange(of: colorScheme)` so `colors` can respond to system changes.
    var systemColorScheme: ColorScheme = .light

    // Always the trait-resolved palette. The effective light/dark is driven by
    // the rendering trait collection (system mode) or `.preferredColorScheme`
    // (forced mode, applied at the root) — never by which ThemeManager instance a
    // view happens to bind to. See `ColorTokens.dynamic`.
    var colors: ColorTokens { .dynamic }

    /// The scheme to force on the hierarchy: `nil` to follow the system, else the
    /// user's explicit choice. The root applies this via `.preferredColorScheme`,
    /// which sets the trait collection that `colors` reads.
    var forcedColorScheme: ColorScheme? {
        switch preference {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var spacing = SpacingTokens()

    func resolvedColorScheme(with systemScheme: ColorScheme) -> ColorScheme {
        switch preference {
        case .system: return systemScheme
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

struct ThemeKey: EnvironmentKey {
    // Default ThemeManager for previews and fallback contexts.
    // Real ThemeManager is injected at app root.
    static let defaultValue: ThemeManager = ThemeManager()
}

// SwiftUI's `EnvironmentValues` requires Sendable types, but ThemeManager is
// a mutable @Observable class holding UI state (`preference`, `colorScheme`).
//
// **Why @unchecked Sendable is safe here:**
// ThemeManager is always accessed on the MainActor via `@Environment(\.theme)`.
// All mutations (`preference = ...`) happen from SwiftUI views, which run on the
// main actor. The environment propagates the reference, not cross-actor copies.
//
// **Why not @MainActor on ThemeManager itself:**
// That would break `ThemeKey.defaultValue = ThemeManager()` — static EnvironmentKey
// defaults are nonisolated, and a MainActor init can't be called from there.
//
// **How to apply:** Only use ThemeManager via `@Environment(\.theme)` or MainActor
// contexts. Do not pass instances across actor boundaries.
extension ThemeManager: @unchecked Sendable {}

extension EnvironmentValues {
    var theme: ThemeManager {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    func withTheme(_ theme: ThemeManager) -> some View {
        self.environment(\.theme, theme)
    }
}
