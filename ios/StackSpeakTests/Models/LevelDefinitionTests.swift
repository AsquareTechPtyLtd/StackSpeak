import Testing
import Foundation
@testable import StackSpeak

/// Thresholds verified against `LevelDefinition.levels` — 60 levels (12 bands × 5),
/// level 2 requires 4 assessment points, level 6 (intermediate gate) requires 26,
/// max level is 60 requiring 1416. One point per correct answer, max two per word.
@Suite("LevelDefinition — progression thresholds")
struct LevelDefinitionTests {

    @Test("Ladder has 60 levels, Intern I … Fellow V")
    func ladderShape() {
        #expect(LevelDefinition.maxLevel == 60)
        #expect(LevelDefinition.definition(for: 1)?.title == "Intern I")
        #expect(LevelDefinition.definition(for: 60)?.title == "Fellow V")
        #expect(LevelDefinition.definition(for: 1)?.pointsRequired == 0)
        #expect(LevelDefinition.definition(for: 60)?.pointsRequired == 1416)
    }

    @Test("Thresholds are strictly increasing")
    func thresholdsMonotonic() {
        let reqs = LevelDefinition.levels.map(\.pointsRequired)
        #expect(zip(reqs, reqs.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("Cannot advance past max level")
    func cannotAdvancePastMaxLevel() {
        #expect(!LevelDefinition.canAdvance(currentLevel: 60, points: 9999))
    }

    @Test("Cannot advance at level 1 with 0 points")
    func cannotAdvanceWithZeroWords() {
        #expect(!LevelDefinition.canAdvance(currentLevel: 1, points: 0))
    }

    @Test("Can advance level 1 → 2 at threshold (4 points)")
    func canAdvanceAtLevel1Threshold() {
        #expect(LevelDefinition.canAdvance(currentLevel: 1, points: 4))
    }

    @Test("Cannot advance level 1 → 2 below threshold")
    func cannotAdvanceBelowThreshold() {
        #expect(!LevelDefinition.canAdvance(currentLevel: 1, points: 3))
    }

    @Test("Single points total can satisfy a multi-level jump check")
    func multiLevelThresholdCrossing() {
        // 26 points clears every threshold up to level 6 (Junior Engineer I).
        #expect(LevelDefinition.canAdvance(currentLevel: 5, points: 26))
        #expect(LevelDefinition.definition(for: 6)?.pointsRequired == 26)
    }

    @Test("Progress is 0 at the start of a band")
    func progressStartsAtZero() {
        let p = LevelDefinition.progressToNextLevel(currentLevel: 1, points: 0)
        #expect(p != nil)
        #expect(p!.progress == 0.0)
        #expect(p!.pointsRemaining == 4)
        #expect(p!.nextLevel.level == 2)
    }

    @Test("Progress is measured within the current level band")
    func progressWithinBand() {
        // Between L2 (req 4) and L3 (req 8): at 6 points, halfway through the band.
        let p = LevelDefinition.progressToNextLevel(currentLevel: 2, points: 6)
        #expect(p!.progress == 0.5)
        #expect(p!.pointsRemaining == 2)
    }

    @Test("Progress clamps at 1.0 when next threshold exceeded")
    func progressClamps() {
        let p = LevelDefinition.progressToNextLevel(currentLevel: 1, points: 100)
        #expect(p!.progress == 1.0)
        #expect(p!.pointsRemaining == 0)
    }

    @Test("progressToNextLevel returns nil at max level")
    func progressAtMaxLevel() {
        #expect(LevelDefinition.progressToNextLevel(currentLevel: 60, points: 999) == nil)
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
