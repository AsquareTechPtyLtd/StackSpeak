import Foundation

struct LevelDefinition {
    let level: Int
    let title: String
    let wordsRequiredWithTwoCorrect: Int
    let description: String

    static let levels: [LevelDefinition] = [
        LevelDefinition(
            level: 1,
            title: "Intern",
            wordsRequiredWithTwoCorrect: 0,
            description: "Starting your vocabulary journey"
        ),
        LevelDefinition(
            level: 2,
            title: "Junior Developer",
            wordsRequiredWithTwoCorrect: 20,
            description: "Building your technical vocabulary foundation"
        ),
        LevelDefinition(
            level: 3,
            title: "Developer",
            wordsRequiredWithTwoCorrect: 50,
            description: "Expanding your professional communication skills"
        ),
        LevelDefinition(
            level: 4,
            title: "Senior Developer",
            wordsRequiredWithTwoCorrect: 120,
            description: "Mastering technical discourse"
        ),
        LevelDefinition(
            level: 5,
            title: "Staff Engineer",
            wordsRequiredWithTwoCorrect: 220,
            description: "Leading with clarity and precision"
        )
    ]

    static func definition(for level: Int) -> LevelDefinition? {
        levels.first { $0.level == level }
    }

    static func nextLevel(after currentLevel: Int) -> LevelDefinition? {
        levels.first { $0.level == currentLevel + 1 }
    }

    static func canAdvance(currentLevel: Int, wordsAssessedCorrectlyTwice: Int) -> Bool {
        guard let nextLevelDef = nextLevel(after: currentLevel) else {
            return false
        }
        return wordsAssessedCorrectlyTwice >= nextLevelDef.wordsRequiredWithTwoCorrect
    }

    static func progressToNextLevel(currentLevel: Int, wordsAssessedCorrectlyTwice: Int) -> LevelProgress? {
        guard let nextLevelDef = nextLevel(after: currentLevel) else {
            return nil
        }

        let progress = min(1.0, Double(wordsAssessedCorrectlyTwice) / Double(nextLevelDef.wordsRequiredWithTwoCorrect))
        let wordsRemaining = max(0, nextLevelDef.wordsRequiredWithTwoCorrect - wordsAssessedCorrectlyTwice)

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
