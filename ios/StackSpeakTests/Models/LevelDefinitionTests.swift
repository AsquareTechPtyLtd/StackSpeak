import Testing
import Foundation
@testable import StackSpeak

/// Thresholds verified against `LevelDefinition.levels` — 60 levels (12 bands × 5),
/// level 2 requires 2 credited words, level 6 (intermediate gate) requires 13,
/// max level is 60 requiring 708.
@Suite("LevelDefinition — progression thresholds")
struct LevelDefinitionTests {

    @Test("Ladder has 60 levels, Intern I … Fellow V")
    func ladderShape() {
        #expect(LevelDefinition.maxLevel == 60)
        #expect(LevelDefinition.definition(for: 1)?.title == "Intern I")
        #expect(LevelDefinition.definition(for: 60)?.title == "Fellow V")
        #expect(LevelDefinition.definition(for: 1)?.wordsRequired == 0)
        #expect(LevelDefinition.definition(for: 60)?.wordsRequired == 708)
    }

    @Test("Thresholds are strictly increasing")
    func thresholdsMonotonic() {
        let reqs = LevelDefinition.levels.map(\.wordsRequired)
        #expect(zip(reqs, reqs.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("Cannot advance past max level")
    func cannotAdvancePastMaxLevel() {
        #expect(!LevelDefinition.canAdvance(currentLevel: 60, wordsCredited: 9999))
    }

    @Test("Cannot advance at level 1 with 0 words")
    func cannotAdvanceWithZeroWords() {
        #expect(!LevelDefinition.canAdvance(currentLevel: 1, wordsCredited: 0))
    }

    @Test("Can advance level 1 → 2 at threshold (2 words)")
    func canAdvanceAtLevel1Threshold() {
        #expect(LevelDefinition.canAdvance(currentLevel: 1, wordsCredited: 2))
    }

    @Test("Cannot advance level 1 → 2 below threshold")
    func cannotAdvanceBelowThreshold() {
        #expect(!LevelDefinition.canAdvance(currentLevel: 1, wordsCredited: 1))
    }

    @Test("Single credit total can satisfy a multi-level jump check")
    func multiLevelThresholdCrossing() {
        // 13 credited words clears every threshold up to level 6 (Junior Engineer I).
        #expect(LevelDefinition.canAdvance(currentLevel: 5, wordsCredited: 13))
        #expect(LevelDefinition.definition(for: 6)?.wordsRequired == 13)
    }

    @Test("Progress is 0 at the start of a band")
    func progressStartsAtZero() {
        let p = LevelDefinition.progressToNextLevel(currentLevel: 1, wordsCredited: 0)
        #expect(p != nil)
        #expect(p!.progress == 0.0)
        #expect(p!.wordsRemaining == 2)
        #expect(p!.nextLevel.level == 2)
    }

    @Test("Progress is measured within the current level band")
    func progressWithinBand() {
        // Between L2 (req 2) and L3 (req 4): at 3 credited, halfway through the band.
        let p = LevelDefinition.progressToNextLevel(currentLevel: 2, wordsCredited: 3)
        #expect(p!.progress == 0.5)
        #expect(p!.wordsRemaining == 1)
    }

    @Test("Progress clamps at 1.0 when next threshold exceeded")
    func progressClamps() {
        let p = LevelDefinition.progressToNextLevel(currentLevel: 1, wordsCredited: 100)
        #expect(p!.progress == 1.0)
        #expect(p!.wordsRemaining == 0)
    }

    @Test("progressToNextLevel returns nil at max level")
    func progressAtMaxLevel() {
        #expect(LevelDefinition.progressToNextLevel(currentLevel: 60, wordsCredited: 999) == nil)
    }

    @Test("Content tier gates land on the documented levels")
    func tierGateLevels() {
        // basic→1, intermediate→6, advanced→16, advanced-2→26, advanced-3→36
        #expect(LevelDefinition.definition(for: 6)?.title == "Junior Engineer I")
        #expect(LevelDefinition.definition(for: 16)?.title == "Senior Engineer I")
        #expect(LevelDefinition.definition(for: 26)?.title == "Staff Engineer I")
        #expect(LevelDefinition.definition(for: 36)?.title == "Principal Engineer I")
    }
}
