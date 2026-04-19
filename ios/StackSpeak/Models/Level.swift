import Foundation

struct LevelDefinition {
    let level: Int
    let title: String
    let wordsRequiredWithTwoCorrect: Int
    let description: String

    static let levels: [LevelDefinition] = [
        LevelDefinition(
            level: 1,
            title: "Intern Band 1",
            wordsRequiredWithTwoCorrect: 0,
            description: "Starting your vocabulary journey"
        ),
        LevelDefinition(
            level: 2,
            title: "Intern Band 2",
            wordsRequiredWithTwoCorrect: 15,
            description: "Building foundational technical vocabulary"
        ),
        LevelDefinition(
            level: 3,
            title: "Junior Band 1",
            wordsRequiredWithTwoCorrect: 35,
            description: "Expanding your professional communication"
        ),
        LevelDefinition(
            level: 4,
            title: "Junior Band 2",
            wordsRequiredWithTwoCorrect: 60,
            description: "Strengthening core technical concepts"
        ),
        LevelDefinition(
            level: 5,
            title: "Mid-Level Band 1",
            wordsRequiredWithTwoCorrect: 90,
            description: "Mastering everyday technical discourse"
        ),
        LevelDefinition(
            level: 6,
            title: "Mid-Level Band 2",
            wordsRequiredWithTwoCorrect: 130,
            description: "Communicating complex technical ideas"
        ),
        LevelDefinition(
            level: 7,
            title: "Senior Band 1",
            wordsRequiredWithTwoCorrect: 180,
            description: "Leading technical discussions with precision"
        ),
        LevelDefinition(
            level: 8,
            title: "Senior Band 2",
            wordsRequiredWithTwoCorrect: 240,
            description: "Architecting solutions through clear communication"
        ),
        LevelDefinition(
            level: 9,
            title: "Staff Band 1",
            wordsRequiredWithTwoCorrect: 310,
            description: "Influencing technical strategy through language"
        ),
        LevelDefinition(
            level: 10,
            title: "Staff Band 2",
            wordsRequiredWithTwoCorrect: 390,
            description: "Setting technical direction with clarity"
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
