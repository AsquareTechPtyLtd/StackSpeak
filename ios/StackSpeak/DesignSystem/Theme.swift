import SwiftUI

@Observable
final class ThemeManager {
    var preference: ThemePreference = .system
    var density: DensityPreference = .roomy

    var colors: ColorTokens {
        switch effectiveColorScheme {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var spacing = SpacingTokens()
    var typography = TypographyTokens.self

    private var effectiveColorScheme: ColorScheme {
        switch preference {
        case .system:
            return .light
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    func resolvedColorScheme(with systemScheme: ColorScheme) -> ColorScheme {
        switch preference {
        case .system:
            return systemScheme
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    func colors(for colorScheme: ColorScheme) -> ColorTokens {
        colorScheme == .light ? .light : .dark
    }
}

struct ThemeKey: EnvironmentKey {
    static let defaultValue = ThemeManager()
}

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
