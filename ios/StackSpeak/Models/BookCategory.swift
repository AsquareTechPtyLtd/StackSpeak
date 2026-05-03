import Foundation
import SwiftUI

/// Locked taxonomy of book categories. Every book carries one or more `BookCategory`
/// values, decoded from the string IDs emitted by `scripts/build-books.js`. Used by
/// the Books tab filter chip row to let the user narrow the catalog.
///
/// The `id` raw values match exactly the strings stored in `book.json` and the
/// `categories` field on `BookSummary` / `BookManifest`. Don't rename them without
/// updating `BOOK_CATEGORIES` in `scripts/build-books.js` and the locked planning
/// docs in `.planning/`.
enum BookCategory: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case aiML = "ai-ml"
    case architecture = "architecture"
    case codeCraft = "code-craft"
    case cloud = "cloud"
    case data = "data"
    case testing = "testing"
    case people = "people"

    var id: String { rawValue }

    /// Localized display name for the chip + filter UI.
    var displayName: LocalizedStringKey {
        switch self {
        case .aiML:         return "category.ai_ml"
        case .architecture: return "category.architecture"
        case .codeCraft:    return "category.code_craft"
        case .cloud:        return "category.cloud"
        case .data:         return "category.data"
        case .testing:      return "category.testing"
        case .people:       return "category.people"
        }
    }

    /// SF Symbol name for the chip icon.
    var icon: String {
        switch self {
        case .aiML:         return "brain.head.profile"
        case .architecture: return "point.3.connected.trianglepath.dotted"
        case .codeCraft:    return "chevron.left.forwardslash.chevron.right"
        case .cloud:        return "cloud.fill"
        case .data:         return "cylinder.split.1x2"
        case .testing:      return "checkmark.shield.fill"
        case .people:       return "bubble.left.and.bubble.right"
        }
    }

    /// Accent hex for the chip's selected-state tint. Independent of theme accent —
    /// these colors are intentionally distinctive so each category reads at a glance.
    /// Light/dark variants are handled by the chip's renderer mixing this with theme tokens.
    var accentHex: String {
        switch self {
        case .aiML:         return "#7E57C2"
        case .architecture: return "#1976D2"
        case .codeCraft:    return "#8E44AD"
        case .cloud:        return "#0078D4"
        case .data:         return "#2A8C8B"
        case .testing:      return "#2E7D32"
        case .people:       return "#FF6B35"
        }
    }

    /// Stable display order across the filter row and any category list.
    /// Matches the order of declaration in this enum so adding a new category
    /// at the end keeps existing positions stable.
    var sortOrder: Int { Self.allCases.firstIndex(of: self) ?? Int.max }

    /// Decodes a category from its raw string ID. Returns `nil` for unknown IDs
    /// rather than throwing — callers (manifest decoding, UI filters) decide whether
    /// to treat unknown IDs as fatal or skip them.
    init?(id: String) {
        self.init(rawValue: id)
    }
}
