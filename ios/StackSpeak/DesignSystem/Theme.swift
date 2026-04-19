import SwiftUI

@Observable
final class ThemeManager {
    var preference: ThemePreference = .system
    var density: DensityPreference = .roomy
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
