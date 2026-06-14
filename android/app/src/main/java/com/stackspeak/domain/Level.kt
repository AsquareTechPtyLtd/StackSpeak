package com.stackspeak.domain

import kotlinx.serialization.Serializable

/** One rung on the 60-level IC ladder (Intern → Fellow). Ported from iOS `Level.swift`. */
@Serializable
data class LevelDefinition(
    val level: Int,
    val title: String,
    val pointsRequired: Int,
    val description: String,
)

/** Progress toward the next level. */
data class LevelProgress(
    val progress: Double,
    val pointsRemaining: Int,
    val nextLevel: LevelDefinition,
)

/**
 * The 60-level table + progression rules, ported verbatim from iOS `Level.swift`
 * (pinned by `levels.json`). `pointsRequired` is cumulative assessment points
 * (one per first-correct, max two per word). Levels never decrease.
 */
object Levels {
    val all: List<LevelDefinition> = listOf(
        LevelDefinition(1, "Intern I", 0, "Starting your vocabulary journey"),
        LevelDefinition(2, "Intern II", 4, "Starting your vocabulary journey"),
        LevelDefinition(3, "Intern III", 8, "Starting your vocabulary journey"),
        LevelDefinition(4, "Intern IV", 14, "Starting your vocabulary journey"),
        LevelDefinition(5, "Intern V", 20, "Starting your vocabulary journey"),
        LevelDefinition(6, "Junior Engineer I", 26, "Building foundational technical vocabulary"),
        LevelDefinition(7, "Junior Engineer II", 34, "Building foundational technical vocabulary"),
        LevelDefinition(8, "Junior Engineer III", 42, "Building foundational technical vocabulary"),
        LevelDefinition(9, "Junior Engineer IV", 50, "Building foundational technical vocabulary"),
        LevelDefinition(10, "Junior Engineer V", 60, "Building foundational technical vocabulary"),
        LevelDefinition(11, "Engineer I", 70, "Expanding your professional communication"),
        LevelDefinition(12, "Engineer II", 80, "Expanding your professional communication"),
        LevelDefinition(13, "Engineer III", 92, "Expanding your professional communication"),
        LevelDefinition(14, "Engineer IV", 104, "Expanding your professional communication"),
        LevelDefinition(15, "Engineer V", 116, "Expanding your professional communication"),
        LevelDefinition(16, "Senior Engineer I", 130, "Strengthening core technical concepts"),
        LevelDefinition(17, "Senior Engineer II", 144, "Strengthening core technical concepts"),
        LevelDefinition(18, "Senior Engineer III", 160, "Strengthening core technical concepts"),
        LevelDefinition(19, "Senior Engineer IV", 176, "Strengthening core technical concepts"),
        LevelDefinition(20, "Senior Engineer V", 192, "Strengthening core technical concepts"),
        LevelDefinition(21, "Lead Engineer I", 210, "Communicating complex ideas with confidence"),
        LevelDefinition(22, "Lead Engineer II", 228, "Communicating complex ideas with confidence"),
        LevelDefinition(23, "Lead Engineer III", 246, "Communicating complex ideas with confidence"),
        LevelDefinition(24, "Lead Engineer IV", 266, "Communicating complex ideas with confidence"),
        LevelDefinition(25, "Lead Engineer V", 286, "Communicating complex ideas with confidence"),
        LevelDefinition(26, "Staff Engineer I", 306, "Mastering advanced technical discourse"),
        LevelDefinition(27, "Staff Engineer II", 328, "Mastering advanced technical discourse"),
        LevelDefinition(28, "Staff Engineer III", 350, "Mastering advanced technical discourse"),
        LevelDefinition(29, "Staff Engineer IV", 372, "Mastering advanced technical discourse"),
        LevelDefinition(30, "Staff Engineer V", 396, "Mastering advanced technical discourse"),
        LevelDefinition(31, "Senior Staff I", 420, "Leading technical discussions with precision"),
        LevelDefinition(32, "Senior Staff II", 444, "Leading technical discussions with precision"),
        LevelDefinition(33, "Senior Staff III", 470, "Leading technical discussions with precision"),
        LevelDefinition(34, "Senior Staff IV", 496, "Leading technical discussions with precision"),
        LevelDefinition(35, "Senior Staff V", 522, "Leading technical discussions with precision"),
        LevelDefinition(36, "Principal Engineer I", 550, "Architecting solutions through clear communication"),
        LevelDefinition(37, "Principal Engineer II", 578, "Architecting solutions through clear communication"),
        LevelDefinition(38, "Principal Engineer III", 606, "Architecting solutions through clear communication"),
        LevelDefinition(39, "Principal Engineer IV", 636, "Architecting solutions through clear communication"),
        LevelDefinition(40, "Principal Engineer V", 666, "Architecting solutions through clear communication"),
        LevelDefinition(41, "Senior Principal I", 696, "Influencing technical strategy through language"),
        LevelDefinition(42, "Senior Principal II", 728, "Influencing technical strategy through language"),
        LevelDefinition(43, "Senior Principal III", 760, "Influencing technical strategy through language"),
        LevelDefinition(44, "Senior Principal IV", 792, "Influencing technical strategy through language"),
        LevelDefinition(45, "Senior Principal V", 826, "Influencing technical strategy through language"),
        LevelDefinition(46, "Architect I", 860, "Designing systems and the words that describe them"),
        LevelDefinition(47, "Architect II", 896, "Designing systems and the words that describe them"),
        LevelDefinition(48, "Architect III", 932, "Designing systems and the words that describe them"),
        LevelDefinition(49, "Architect IV", 968, "Designing systems and the words that describe them"),
        LevelDefinition(50, "Architect V", 1006, "Designing systems and the words that describe them"),
        LevelDefinition(51, "Distinguished Engineer I", 1044, "Setting technical direction with clarity"),
        LevelDefinition(52, "Distinguished Engineer II", 1082, "Setting technical direction with clarity"),
        LevelDefinition(53, "Distinguished Engineer III", 1122, "Setting technical direction with clarity"),
        LevelDefinition(54, "Distinguished Engineer IV", 1162, "Setting technical direction with clarity"),
        LevelDefinition(55, "Distinguished Engineer V", 1202, "Setting technical direction with clarity"),
        LevelDefinition(56, "Fellow I", 1244, "Command of the full technical vocabulary"),
        LevelDefinition(57, "Fellow II", 1286, "Command of the full technical vocabulary"),
        LevelDefinition(58, "Fellow III", 1328, "Command of the full technical vocabulary"),
        LevelDefinition(59, "Fellow IV", 1372, "Command of the full technical vocabulary"),
        LevelDefinition(60, "Fellow V", 1416, "Command of the full technical vocabulary"),
    )

    val maxLevel: Int get() = all.size

    fun definition(level: Int): LevelDefinition? = all.firstOrNull { it.level == level }

    fun nextLevel(after: Int): LevelDefinition? = all.firstOrNull { it.level == after + 1 }

    /** Whether [points] is enough to advance past [currentLevel]. */
    fun canAdvance(currentLevel: Int, points: Int): Boolean {
        val next = nextLevel(currentLevel) ?: return false
        return points >= next.pointsRequired
    }

    fun progressToNextLevel(currentLevel: Int, points: Int): LevelProgress? {
        val next = nextLevel(currentLevel) ?: return null
        val currentThreshold = definition(currentLevel)?.pointsRequired ?: 0
        val span = maxOf(1, next.pointsRequired - currentThreshold)
        val earned = maxOf(0, points - currentThreshold)
        val progress = minOf(1.0, earned.toDouble() / span.toDouble())
        val pointsRemaining = maxOf(0, next.pointsRequired - points)
        return LevelProgress(progress, pointsRemaining, next)
    }
}
