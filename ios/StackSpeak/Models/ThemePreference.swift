import Foundation

enum ThemePreference: String, Codable {
    case system
    case light
    case dark

    /// Localized display name — never surface `rawValue` in UI.
    var displayName: String {
        switch self {
        case .system: String(localized: "settings.theme.system")
        case .light:  String(localized: "settings.theme.light")
        case .dark:   String(localized: "settings.theme.dark")
        }
    }
}
