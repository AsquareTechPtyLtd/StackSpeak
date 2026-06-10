import SwiftUI

/// Categorical accent colors for the Books filter chips. Lives in the design
/// system (not the `BookCategory` model) so color decisions stay alongside the
/// other tokens. Independent of the theme accent — these are intentionally
/// distinctive so each category reads at a glance; light/dark handling is done
/// by the chip renderer mixing this with theme tokens.
extension BookCategory {
    var accentColor: Color {
        switch self {
        case .aiML:         return Color(hex: "#7E57C2")
        case .architecture: return Color(hex: "#1976D2")
        case .codeCraft:    return Color(hex: "#8E44AD")
        case .cloud:        return Color(hex: "#0078D4")
        case .data:         return Color(hex: "#2A8C8B")
        case .testing:      return Color(hex: "#2E7D32")
        case .people:       return Color(hex: "#FF6B35")
        }
    }
}
