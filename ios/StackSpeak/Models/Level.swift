import Foundation

/// One rung on the 60-level IC career ladder (12 bands × 5 sub-levels, Intern → Fellow).
///
/// `pointsRequired` is the progression currency threshold: cumulative **assessment
/// points**. Every correct assessment answer earns one point, and a word can earn
/// at most two — its first correct, and a second correct on a later day
/// (`canAttemptAssessment` blocks same-day reattempts). See
/// `UserProgress.assessmentPointsForLevel`.
///
/// Content tiers unlock at fixed levels, baked into each word's `unlockLevel` and
/// each stack's `minimumLevel` at authoring time: basic→1, intermediate→6,
/// advanced→16, advanced-2→26, advanced-3→36. All content is reachable by Principal
/// (L36); the top four bands (Senior Principal → Fellow) are prestige mastery.
struct LevelDefinition: Codable {
    let level: Int
    let title: String
    let pointsRequired: Int
    let description: String

    static let levels: [LevelDefinition] = [
        LevelDefinition(level: 1, title: "Intern I", pointsRequired: 0, description: "Starting your vocabulary journey"),
        LevelDefinition(level: 2, title: "Intern II", pointsRequired: 4, description: "Starting your vocabulary journey"),
        LevelDefinition(level: 3, title: "Intern III", pointsRequired: 8, description: "Starting your vocabulary journey"),
        LevelDefinition(level: 4, title: "Intern IV", pointsRequired: 14, description: "Starting your vocabulary journey"),
        LevelDefinition(level: 5, title: "Intern V", pointsRequired: 20, description: "Starting your vocabulary journey"),
        LevelDefinition(level: 6, title: "Junior Engineer I", pointsRequired: 26, description: "Building foundational technical vocabulary"),
        LevelDefinition(level: 7, title: "Junior Engineer II", pointsRequired: 34, description: "Building foundational technical vocabulary"),
        LevelDefinition(level: 8, title: "Junior Engineer III", pointsRequired: 42, description: "Building foundational technical vocabulary"),
        LevelDefinition(level: 9, title: "Junior Engineer IV", pointsRequired: 50, description: "Building foundational technical vocabulary"),
        LevelDefinition(level: 10, title: "Junior Engineer V", pointsRequired: 60, description: "Building foundational technical vocabulary"),
        LevelDefinition(level: 11, title: "Engineer I", pointsRequired: 70, description: "Expanding your professional communication"),
        LevelDefinition(level: 12, title: "Engineer II", pointsRequired: 80, description: "Expanding your professional communication"),
        LevelDefinition(level: 13, title: "Engineer III", pointsRequired: 92, description: "Expanding your professional communication"),
        LevelDefinition(level: 14, title: "Engineer IV", pointsRequired: 104, description: "Expanding your professional communication"),
        LevelDefinition(level: 15, title: "Engineer V", pointsRequired: 116, description: "Expanding your professional communication"),
        LevelDefinition(level: 16, title: "Senior Engineer I", pointsRequired: 130, description: "Strengthening core technical concepts"),
        LevelDefinition(level: 17, title: "Senior Engineer II", pointsRequired: 144, description: "Strengthening core technical concepts"),
        LevelDefinition(level: 18, title: "Senior Engineer III", pointsRequired: 160, description: "Strengthening core technical concepts"),
        LevelDefinition(level: 19, title: "Senior Engineer IV", pointsRequired: 176, description: "Strengthening core technical concepts"),
        LevelDefinition(level: 20, title: "Senior Engineer V", pointsRequired: 192, description: "Strengthening core technical concepts"),
        LevelDefinition(level: 21, title: "Lead Engineer I", pointsRequired: 210, description: "Communicating complex ideas with confidence"),
        LevelDefinition(level: 22, title: "Lead Engineer II", pointsRequired: 228, description: "Communicating complex ideas with confidence"),
        LevelDefinition(level: 23, title: "Lead Engineer III", pointsRequired: 246, description: "Communicating complex ideas with confidence"),
        LevelDefinition(level: 24, title: "Lead Engineer IV", pointsRequired: 266, description: "Communicating complex ideas with confidence"),
        LevelDefinition(level: 25, title: "Lead Engineer V", pointsRequired: 286, description: "Communicating complex ideas with confidence"),
        LevelDefinition(level: 26, title: "Staff Engineer I", pointsRequired: 306, description: "Mastering advanced technical discourse"),
        LevelDefinition(level: 27, title: "Staff Engineer II", pointsRequired: 328, description: "Mastering advanced technical discourse"),
        LevelDefinition(level: 28, title: "Staff Engineer III", pointsRequired: 350, description: "Mastering advanced technical discourse"),
        LevelDefinition(level: 29, title: "Staff Engineer IV", pointsRequired: 372, description: "Mastering advanced technical discourse"),
        LevelDefinition(level: 30, title: "Staff Engineer V", pointsRequired: 396, description: "Mastering advanced technical discourse"),
        LevelDefinition(level: 31, title: "Senior Staff I", pointsRequired: 420, description: "Leading technical discussions with precision"),
        LevelDefinition(level: 32, title: "Senior Staff II", pointsRequired: 444, description: "Leading technical discussions with precision"),
        LevelDefinition(level: 33, title: "Senior Staff III", pointsRequired: 470, description: "Leading technical discussions with precision"),
        LevelDefinition(level: 34, title: "Senior Staff IV", pointsRequired: 496, description: "Leading technical discussions with precision"),
        LevelDefinition(level: 35, title: "Senior Staff V", pointsRequired: 522, description: "Leading technical discussions with precision"),
        LevelDefinition(level: 36, title: "Principal Engineer I", pointsRequired: 550, description: "Architecting solutions through clear communication"),
        LevelDefinition(level: 37, title: "Principal Engineer II", pointsRequired: 578, description: "Architecting solutions through clear communication"),
        LevelDefinition(level: 38, title: "Principal Engineer III", pointsRequired: 606, description: "Architecting solutions through clear communication"),
        LevelDefinition(level: 39, title: "Principal Engineer IV", pointsRequired: 636, description: "Architecting solutions through clear communication"),
        LevelDefinition(level: 40, title: "Principal Engineer V", pointsRequired: 666, description: "Architecting solutions through clear communication"),
        LevelDefinition(level: 41, title: "Senior Principal I", pointsRequired: 696, description: "Influencing technical strategy through language"),
        LevelDefinition(level: 42, title: "Senior Principal II", pointsRequired: 728, description: "Influencing technical strategy through language"),
        LevelDefinition(level: 43, title: "Senior Principal III", pointsRequired: 760, description: "Influencing technical strategy through language"),
        LevelDefinition(level: 44, title: "Senior Principal IV", pointsRequired: 792, description: "Influencing technical strategy through language"),
        LevelDefinition(level: 45, title: "Senior Principal V", pointsRequired: 826, description: "Influencing technical strategy through language"),
        LevelDefinition(level: 46, title: "Architect I", pointsRequired: 860, description: "Designing systems and the words that describe them"),
        LevelDefinition(level: 47, title: "Architect II", pointsRequired: 896, description: "Designing systems and the words that describe them"),
        LevelDefinition(level: 48, title: "Architect III", pointsRequired: 932, description: "Designing systems and the words that describe them"),
        LevelDefinition(level: 49, title: "Architect IV", pointsRequired: 968, description: "Designing systems and the words that describe them"),
        LevelDefinition(level: 50, title: "Architect V", pointsRequired: 1006, description: "Designing systems and the words that describe them"),
        LevelDefinition(level: 51, title: "Distinguished Engineer I", pointsRequired: 1044, description: "Setting technical direction with clarity"),
        LevelDefinition(level: 52, title: "Distinguished Engineer II", pointsRequired: 1082, description: "Setting technical direction with clarity"),
        LevelDefinition(level: 53, title: "Distinguished Engineer III", pointsRequired: 1122, description: "Setting technical direction with clarity"),
        LevelDefinition(level: 54, title: "Distinguished Engineer IV", pointsRequired: 1162, description: "Setting technical direction with clarity"),
        LevelDefinition(level: 55, title: "Distinguished Engineer V", pointsRequired: 1202, description: "Setting technical direction with clarity"),
        LevelDefinition(level: 56, title: "Fellow I", pointsRequired: 1244, description: "Command of the full technical vocabulary"),
        LevelDefinition(level: 57, title: "Fellow II", pointsRequired: 1286, description: "Command of the full technical vocabulary"),
        LevelDefinition(level: 58, title: "Fellow III", pointsRequired: 1328, description: "Command of the full technical vocabulary"),
        LevelDefinition(level: 59, title: "Fellow IV", pointsRequired: 1372, description: "Command of the full technical vocabulary"),
        LevelDefinition(level: 60, title: "Fellow V", pointsRequired: 1416, description: "Command of the full technical vocabulary"),
    ]

    /// Highest level in the ladder.
    static var maxLevel: Int { levels.count }

    static func definition(for level: Int) -> LevelDefinition? {
        levels.first { $0.level == level }
    }

    static func nextLevel(after currentLevel: Int) -> LevelDefinition? {
        levels.first { $0.level == currentLevel + 1 }
    }

    /// Whether the user has enough assessment points to advance past `currentLevel`.
    static func canAdvance(currentLevel: Int, points: Int) -> Bool {
        guard let nextLevelDef = nextLevel(after: currentLevel) else {
            return false
        }
        return points >= nextLevelDef.pointsRequired
    }

    static func progressToNextLevel(currentLevel: Int, points: Int) -> LevelProgress? {
        guard let nextLevelDef = nextLevel(after: currentLevel) else {
            return nil
        }

        let currentThreshold = definition(for: currentLevel)?.pointsRequired ?? 0
        let span = max(1, nextLevelDef.pointsRequired - currentThreshold)
        let earned = max(0, points - currentThreshold)
        let progress = min(1.0, Double(earned) / Double(span))
        let pointsRemaining = max(0, nextLevelDef.pointsRequired - points)

        return LevelProgress(
            progress: progress,
            pointsRemaining: pointsRemaining,
            nextLevel: nextLevelDef
        )
    }
}
