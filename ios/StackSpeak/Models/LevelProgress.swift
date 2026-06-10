import Foundation

struct LevelProgress: Codable {
    let progress: Double
    let wordsRemaining: Int
    let nextLevel: LevelDefinition

    var isReady: Bool {
        progress >= 1.0
    }
}
