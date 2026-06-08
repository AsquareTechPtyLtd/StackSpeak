import Foundation

/// One rung on the 60-level IC career ladder (12 bands × 5 sub-levels, Intern → Fellow).
///
/// `wordsRequired` is the progression currency threshold: the cumulative number of
/// words the user has **credited toward leveling** — a word is credited on its first
/// correct assessment answer (see `UserProgress.wordsAssessedForLevel`). The second
/// correct answer is tracked separately as a retention stat and does not gate levels.
///
/// Content tiers unlock at fixed levels, baked into each word's `unlockLevel` and
/// each stack's `minimumLevel` at authoring time: basic→1, intermediate→6,
/// advanced→16, advanced-2→26, advanced-3→36. All content is reachable by Principal
/// (L36); the top four bands (Senior Principal → Fellow) are prestige mastery.
struct LevelDefinition {
    let level: Int
    let title: String
    let wordsRequired: Int
    let description: String

    static let levels: [LevelDefinition] = [
        LevelDefinition(level: 1, title: "Intern I", wordsRequired: 0, description: "Starting your vocabulary journey"),
        LevelDefinition(level: 2, title: "Intern II", wordsRequired: 2, description: "Starting your vocabulary journey"),
        LevelDefinition(level: 3, title: "Intern III", wordsRequired: 4, description: "Starting your vocabulary journey"),
        LevelDefinition(level: 4, title: "Intern IV", wordsRequired: 7, description: "Starting your vocabulary journey"),
        LevelDefinition(level: 5, title: "Intern V", wordsRequired: 10, description: "Starting your vocabulary journey"),
        LevelDefinition(level: 6, title: "Junior Engineer I", wordsRequired: 13, description: "Building foundational technical vocabulary"),
        LevelDefinition(level: 7, title: "Junior Engineer II", wordsRequired: 17, description: "Building foundational technical vocabulary"),
        LevelDefinition(level: 8, title: "Junior Engineer III", wordsRequired: 21, description: "Building foundational technical vocabulary"),
        LevelDefinition(level: 9, title: "Junior Engineer IV", wordsRequired: 25, description: "Building foundational technical vocabulary"),
        LevelDefinition(level: 10, title: "Junior Engineer V", wordsRequired: 30, description: "Building foundational technical vocabulary"),
        LevelDefinition(level: 11, title: "Engineer I", wordsRequired: 35, description: "Expanding your professional communication"),
        LevelDefinition(level: 12, title: "Engineer II", wordsRequired: 40, description: "Expanding your professional communication"),
        LevelDefinition(level: 13, title: "Engineer III", wordsRequired: 46, description: "Expanding your professional communication"),
        LevelDefinition(level: 14, title: "Engineer IV", wordsRequired: 52, description: "Expanding your professional communication"),
        LevelDefinition(level: 15, title: "Engineer V", wordsRequired: 58, description: "Expanding your professional communication"),
        LevelDefinition(level: 16, title: "Senior Engineer I", wordsRequired: 65, description: "Strengthening core technical concepts"),
        LevelDefinition(level: 17, title: "Senior Engineer II", wordsRequired: 72, description: "Strengthening core technical concepts"),
        LevelDefinition(level: 18, title: "Senior Engineer III", wordsRequired: 80, description: "Strengthening core technical concepts"),
        LevelDefinition(level: 19, title: "Senior Engineer IV", wordsRequired: 88, description: "Strengthening core technical concepts"),
        LevelDefinition(level: 20, title: "Senior Engineer V", wordsRequired: 96, description: "Strengthening core technical concepts"),
        LevelDefinition(level: 21, title: "Lead Engineer I", wordsRequired: 105, description: "Communicating complex ideas with confidence"),
        LevelDefinition(level: 22, title: "Lead Engineer II", wordsRequired: 114, description: "Communicating complex ideas with confidence"),
        LevelDefinition(level: 23, title: "Lead Engineer III", wordsRequired: 123, description: "Communicating complex ideas with confidence"),
        LevelDefinition(level: 24, title: "Lead Engineer IV", wordsRequired: 133, description: "Communicating complex ideas with confidence"),
        LevelDefinition(level: 25, title: "Lead Engineer V", wordsRequired: 143, description: "Communicating complex ideas with confidence"),
        LevelDefinition(level: 26, title: "Staff Engineer I", wordsRequired: 153, description: "Mastering advanced technical discourse"),
        LevelDefinition(level: 27, title: "Staff Engineer II", wordsRequired: 164, description: "Mastering advanced technical discourse"),
        LevelDefinition(level: 28, title: "Staff Engineer III", wordsRequired: 175, description: "Mastering advanced technical discourse"),
        LevelDefinition(level: 29, title: "Staff Engineer IV", wordsRequired: 186, description: "Mastering advanced technical discourse"),
        LevelDefinition(level: 30, title: "Staff Engineer V", wordsRequired: 198, description: "Mastering advanced technical discourse"),
        LevelDefinition(level: 31, title: "Senior Staff I", wordsRequired: 210, description: "Leading technical discussions with precision"),
        LevelDefinition(level: 32, title: "Senior Staff II", wordsRequired: 222, description: "Leading technical discussions with precision"),
        LevelDefinition(level: 33, title: "Senior Staff III", wordsRequired: 235, description: "Leading technical discussions with precision"),
        LevelDefinition(level: 34, title: "Senior Staff IV", wordsRequired: 248, description: "Leading technical discussions with precision"),
        LevelDefinition(level: 35, title: "Senior Staff V", wordsRequired: 261, description: "Leading technical discussions with precision"),
        LevelDefinition(level: 36, title: "Principal Engineer I", wordsRequired: 275, description: "Architecting solutions through clear communication"),
        LevelDefinition(level: 37, title: "Principal Engineer II", wordsRequired: 289, description: "Architecting solutions through clear communication"),
        LevelDefinition(level: 38, title: "Principal Engineer III", wordsRequired: 303, description: "Architecting solutions through clear communication"),
        LevelDefinition(level: 39, title: "Principal Engineer IV", wordsRequired: 318, description: "Architecting solutions through clear communication"),
        LevelDefinition(level: 40, title: "Principal Engineer V", wordsRequired: 333, description: "Architecting solutions through clear communication"),
        LevelDefinition(level: 41, title: "Senior Principal I", wordsRequired: 348, description: "Influencing technical strategy through language"),
        LevelDefinition(level: 42, title: "Senior Principal II", wordsRequired: 364, description: "Influencing technical strategy through language"),
        LevelDefinition(level: 43, title: "Senior Principal III", wordsRequired: 380, description: "Influencing technical strategy through language"),
        LevelDefinition(level: 44, title: "Senior Principal IV", wordsRequired: 396, description: "Influencing technical strategy through language"),
        LevelDefinition(level: 45, title: "Senior Principal V", wordsRequired: 413, description: "Influencing technical strategy through language"),
        LevelDefinition(level: 46, title: "Architect I", wordsRequired: 430, description: "Designing systems and the words that describe them"),
        LevelDefinition(level: 47, title: "Architect II", wordsRequired: 448, description: "Designing systems and the words that describe them"),
        LevelDefinition(level: 48, title: "Architect III", wordsRequired: 466, description: "Designing systems and the words that describe them"),
        LevelDefinition(level: 49, title: "Architect IV", wordsRequired: 484, description: "Designing systems and the words that describe them"),
        LevelDefinition(level: 50, title: "Architect V", wordsRequired: 503, description: "Designing systems and the words that describe them"),
        LevelDefinition(level: 51, title: "Distinguished Engineer I", wordsRequired: 522, description: "Setting technical direction with clarity"),
        LevelDefinition(level: 52, title: "Distinguished Engineer II", wordsRequired: 541, description: "Setting technical direction with clarity"),
        LevelDefinition(level: 53, title: "Distinguished Engineer III", wordsRequired: 561, description: "Setting technical direction with clarity"),
        LevelDefinition(level: 54, title: "Distinguished Engineer IV", wordsRequired: 581, description: "Setting technical direction with clarity"),
        LevelDefinition(level: 55, title: "Distinguished Engineer V", wordsRequired: 601, description: "Setting technical direction with clarity"),
        LevelDefinition(level: 56, title: "Fellow I", wordsRequired: 622, description: "Command of the full technical vocabulary"),
        LevelDefinition(level: 57, title: "Fellow II", wordsRequired: 643, description: "Command of the full technical vocabulary"),
        LevelDefinition(level: 58, title: "Fellow III", wordsRequired: 664, description: "Command of the full technical vocabulary"),
        LevelDefinition(level: 59, title: "Fellow IV", wordsRequired: 686, description: "Command of the full technical vocabulary"),
        LevelDefinition(level: 60, title: "Fellow V", wordsRequired: 708, description: "Command of the full technical vocabulary"),
    ]

    /// Highest level in the ladder.
    static var maxLevel: Int { levels.count }

    static func definition(for level: Int) -> LevelDefinition? {
        levels.first { $0.level == level }
    }

    static func nextLevel(after currentLevel: Int) -> LevelDefinition? {
        levels.first { $0.level == currentLevel + 1 }
    }

    /// Whether the user has enough credited words to advance past `currentLevel`.
    static func canAdvance(currentLevel: Int, wordsCredited: Int) -> Bool {
        guard let nextLevelDef = nextLevel(after: currentLevel) else {
            return false
        }
        return wordsCredited >= nextLevelDef.wordsRequired
    }

    static func progressToNextLevel(currentLevel: Int, wordsCredited: Int) -> LevelProgress? {
        guard let nextLevelDef = nextLevel(after: currentLevel) else {
            return nil
        }

        let currentThreshold = definition(for: currentLevel)?.wordsRequired ?? 0
        let span = max(1, nextLevelDef.wordsRequired - currentThreshold)
        let earned = max(0, wordsCredited - currentThreshold)
        let progress = min(1.0, Double(earned) / Double(span))
        let wordsRemaining = max(0, nextLevelDef.wordsRequired - wordsCredited)

        return LevelProgress(
            progress: progress,
            wordsRemaining: wordsRemaining,
            nextLevel: nextLevelDef
        )
    }
}

struct LevelProgress {
    let progress: Double
    let wordsRemaining: Int
    let nextLevel: LevelDefinition

    var isReady: Bool {
        progress >= 1.0
    }
}
