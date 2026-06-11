import Foundation

struct LevelProgress: Codable {
    let progress: Double
    /// Assessment points (correct answers, max two per word) still needed.
    let pointsRemaining: Int
    let nextLevel: LevelDefinition

    var isReady: Bool {
        progress >= 1.0
    }
}
