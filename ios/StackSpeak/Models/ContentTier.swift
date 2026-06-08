import Foundation

/// A content difficulty tier. Each tier's content unlocks at a fixed level on the
/// 60-level ladder (see `LevelDefinition`); a word's tier is derived from its
/// `unlockLevel`, which is set from the tier at authoring time.
enum ContentTier: Int, CaseIterable {
    case basic = 1
    case intermediate = 6
    case advanced = 16
    case advancedII = 26
    case advancedIII = 36

    /// The level at which this tier's content unlocks.
    var unlockLevel: Int { rawValue }

    /// Localized display name for badges and callouts.
    var displayName: String {
        switch self {
        case .basic: String(localized: "tier.basic")
        case .intermediate: String(localized: "tier.intermediate")
        case .advanced: String(localized: "tier.advanced")
        case .advancedII: String(localized: "tier.advanced2")
        case .advancedIII: String(localized: "tier.advanced3")
        }
    }

    /// The tier a word belongs to, given its `unlockLevel`. Words are normalized to
    /// exact gate values; the fallback covers any legacy/off-gate value by picking
    /// the highest tier whose gate is at or below `level`.
    static func forUnlockLevel(_ level: Int) -> ContentTier {
        ContentTier(rawValue: level) ?? allCases.last { $0.rawValue <= level } ?? .basic
    }

    /// The tier newly opened at `level`, if `level` is exactly a tier gate.
    /// Returns `nil` for rank-only levels (no new content).
    static func unlockedAt(level: Int) -> ContentTier? {
        ContentTier(rawValue: level)
    }
}
