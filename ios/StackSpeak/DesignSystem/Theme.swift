import SwiftUI

@Observable
final class ThemeManager {
    var preference: ThemePreference = .system
    /// Set by the root view via `.onChange(of: colorScheme)` so `colors` can respond to system changes.
    var systemColorScheme: ColorScheme = .light

    var colors: ColorTokens {
        switch preference {
        case .system: return systemColorScheme == .dark ? .dark : .light
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

    func colors(for colorScheme: ColorScheme) -> ColorTokens {
        colorScheme == .dark ? .dark : .light
    }
}

struct ThemeKey: EnvironmentKey {
    // Default ThemeManager for previews and fallback contexts.
    // Real ThemeManager is injected at app root.
    static let defaultValue: ThemeManager = ThemeManager()
}

// Required: ThemeManager is stored in EnvironmentValues (which is Sendable), but
// it's a mutable @Observable holding UI state. Full @MainActor isolation would
// break `ThemeKey.defaultValue = ThemeManager()` (nonisolated static init). In
// practice it's only ever mutated on the main actor via SwiftUI.
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
