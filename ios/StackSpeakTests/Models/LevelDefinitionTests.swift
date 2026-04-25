import Testing
import Foundation
@testable import StackSpeak

/// Thresholds verified against `LevelDefinition.levels` — 10 levels, level 2
/// requires 15, max level is 10.
@Suite("LevelDefinition — progression thresholds")
struct LevelDefinitionTests {

    @Test("Cannot advance past max level")
    func cannotAdvancePastMaxLevel() {
        #expect(!LevelDefinition.canAdvance(currentLevel: 10, wordsAssessedCorrectlyTwice: 9999))
    }

    @Test("Cannot advance at level 1 with 0 words")
    func cannotAdvanceWithZeroWords() {
        #expect(!LevelDefinition.canAdvance(currentLevel: 1, wordsAssessedCorrectlyTwice: 0))
    }

    @Test("Can advance level 1 → 2 at threshold (15 words)")
    func canAdvanceAtLevel1Threshold() {
        #expect(LevelDefinition.canAdvance(currentLevel: 1, wordsAssessedCorrectlyTwice: 15))
    }

    @Test("Cannot advance level 1 → 2 below threshold")
    func cannotAdvanceBelowThreshold() {
        #expect(!LevelDefinition.canAdvance(currentLevel: 1, wordsAssessedCorrectlyTwice: 14))
    }

    @Test("Progress to next level returns 0 at start")
    func progressStartsAtZero() {
        let p = LevelDefinition.progressToNextLevel(currentLevel: 1, wordsAssessedCorrectlyTwice: 0)
        #expect(p != nil)
        #expect(p!.progress == 0.0)
        #expect(p!.wordsRemaining == 15)
    }

    @Test("Progress clamps at 1.0 when threshold exceeded")
    func progressClamps() {
        let p = LevelDefinition.progressToNextLevel(currentLevel: 1, wordsAssessedCorrectlyTwice: 100)
        #expect(p!.progress == 1.0)
        #expect(p!.wordsRemaining == 0)
    }

    @Test("progressToNextLevel returns nil at max level")
    func progressAtMaxLevel() {
        #expect(LevelDefinition.progressToNextLevel(currentLevel: 10, wordsAssessedCorrectlyTwice: 999) == nil)
    }
}
