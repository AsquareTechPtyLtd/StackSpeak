import Testing
import Foundation
import SwiftData
@testable import StackSpeak

// Generates (first run / `GENERATE_FIXTURES=1`) and otherwise validates the
// cross-platform golden fixtures in `shared/test-fixtures/`. Each `#expect`
// fails if determinism-critical code drifts from the committed bytes — at which
// point the fixtures are regenerated intentionally and reviewed in the diff.
@Suite("Cross-platform golden fixtures")
@MainActor
struct FixtureGenerationTests {

    private let store = FixtureStore()

    // MARK: - Determinism primitives (§1.4)

    @Test("primitives: stableHash, deterministicUUID, SeededRandomGenerator")
    func primitives() throws {
        let hashInputs = ["", "a", "cache", "api-bas-0001-cache", "gcp-bas-0010-vpc", "StackSpeak"]
        let uuidInputs = ["api-bas-0001-cache", "gcp-bas-0010-vpc", "azure-adv-0042-bicep", "msv-adv-0010-saga"]
        let rngSeeds = ["seed", "api-bas-0001-cache", "v1"]

        let fixture = PrimitivesFixture(
            note: "FNV-1a 64 (stableHash), two-stream deterministicUUID (no RFC version/variant bits), "
                + "and the MMIX LCG SeededRandomGenerator. u64 values are decimal strings. "
                + "UUID strings are UPPERCASE (Swift .uuidString) — Android must uppercase to match.",
            stableHash: hashInputs.map { .init(input: $0, stableHash: String(stableHash($0))) },
            deterministicUUID: uuidInputs.map { .init(input: $0, uuid: deterministicUUID(from: $0).uuidString) },
            seededRandom: rngSeeds.map { s in
                var rng = SeededRandomGenerator(seed: stableHash(s))
                let seq = (0..<8).map { _ in String(rng.next()) }
                return .init(seedString: s, seed: String(stableHash(s)), sequence: seq)
            }
        )
        #expect(try store.sync(fixture, to: "primitives.json"))
    }

    // MARK: - SM-2 spaced repetition (§1.3)

    @Test("sm2: review-state transitions for each grade path")
    func sm2() throws {
        let cal = FixtureClock.utc
        let at = FixtureClock.epoch

        func run(_ name: String, mnemonic: String, grades: [Int]) -> SM2Sequence {
            let wordId = deterministicUUID(from: mnemonic)
            let rs = ReviewState(wordId: wordId, now: at, calendar: cal)
            let initial = SM2State(easinessFactor: rs.easinessFactor, interval: rs.interval,
                                   repetitions: rs.repetitions, dueDate: rs.dueDate, lastReviewedAt: rs.lastReviewedAt)
            var steps: [SM2State] = []
            for g in grades {
                rs.updateAfterReview(quality: g, now: at, calendar: cal)
                steps.append(.init(easinessFactor: rs.easinessFactor, interval: rs.interval,
                                   repetitions: rs.repetitions, dueDate: rs.dueDate, lastReviewedAt: rs.lastReviewedAt))
            }
            return SM2Sequence(name: name, wordId: wordId.uuidString, appliedAt: at,
                               grades: grades, initial: initial, afterEachGrade: steps)
        }

        // Grades: again=2, good=4, easy=5.
        let fixture = SM2Fixture(
            note: "EF updates on every review (incl. lapses). Due date = appliedAt + jittered offset "
                + "(jitter from wordId's native UUID bytes via FNV-1a). All reviews applied at the same "
                + "instant so dueDate isolates the interval ladder. Calendar = UTC.",
            calendar: "UTC",
            sequences: [
                run("all-good", mnemonic: "api-bas-0001-cache", grades: [4, 4, 4, 4]),
                run("all-easy", mnemonic: "gcp-bas-0010-vpc", grades: [5, 5, 5]),
                run("lapse-then-recover", mnemonic: "msv-adv-0010-saga", grades: [4, 4, 2, 4, 4]),
                run("immediate-fail", mnemonic: "azure-adv-0042-bicep", grades: [2, 2]),
            ]
        )
        #expect(try store.sync(fixture, to: "sm2.json"))
    }

    // MARK: - Level table (§1.6)

    @Test("levels: the full 60-level ladder")
    func levels() throws {
        #expect(try store.sync(LevelDefinition.levels, to: "levels.json"))
    }

    // MARK: - Deterministic shuffle (§1.5)

    @Test("shuffle: deterministicShuffle for a fixed seed")
    func shuffle() throws {
        let service = try makeService()
        let seed = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let words = (1...12).map { mockWord("shuf-\($0)", category: "concepts") }

        let shuffled = service.deterministicShuffle(words, seed: seed)
        let fixture = ShuffleFixture(
            note: "Sort by id.uuidString, then Fisher-Yates driven by "
                + "SeededRandomGenerator(stableHash(seed.uuidString + \"v1\")). UUIDs UPPERCASE.",
            cases: [.init(name: "12-words", seed: seed.uuidString,
                          inputIds: words.map { $0.id.uuidString },
                          outputIds: shuffled.map { $0.id.uuidString })]
        )
        #expect(try store.sync(fixture, to: "shuffle.json"))
    }

    // MARK: - Daily selection / category interleaving (§1.5)

    @Test("selection: selectQualifyingWords category interleaving + backfill")
    func selection() throws {
        let service = try makeService()
        let cats = ["concepts", "components", "processes", "patterns", "qualities"]

        func selectionCase(_ name: String, words: [Word], level: Int,
                           stacks: Set<String>, mastered: [Word], start: Int) -> SelectionCase {
            let progress = mockProgress(stacks: stacks, level: level)
            progress.masteredWordIds = Set(mastered.map { $0.id })
            let (selected, next) = service.selectQualifyingWords(
                from: words, startingAt: start, userProgress: progress, count: 5)
            return SelectionCase(
                name: name, level: level, selectedStacks: stacks.sorted(),
                masteredIds: mastered.map { $0.id.uuidString }.sorted(),
                startCursor: start, count: 5,
                inputWordIds: words.map { $0.id.uuidString },
                selectedWordIds: selected.map { $0.id.uuidString }, nextCursor: next)
        }

        // Balanced: one per distinct category, queue order preserved.
        let balanced = cats.enumerated().map { mockWord("bal-\($0.offset)", category: $0.element) }
        // Backfill: only two categories, so result fills from the backfill pool.
        let backfill = (1...8).map { mockWord("bf-\($0)", category: $0.isMultiple(of: 2) ? "concepts" : "components") }
        // Mastered excluded.
        let withMastered = (1...6).map { mockWord("ms-\($0)", category: cats[$0 % cats.count]) }

        let fixture = SelectionFixture(
            note: "Walk the ring from startCursor using effectiveSelectedStacks; take the first "
                + "qualifying word per distinct category (first-seen order), then backfill to count. "
                + "Returns the advanced cursor even when fewer than count qualify. UUIDs UPPERCASE.",
            cases: [
                selectionCase("balanced", words: balanced, level: 5, stacks: ["test-stack"], mastered: [], start: 0),
                selectionCase("backfill-two-categories", words: backfill, level: 5, stacks: ["test-stack"], mastered: [], start: 0),
                selectionCase("excludes-mastered", words: withMastered, level: 5, stacks: ["test-stack"],
                              mastered: [withMastered[0]], start: 0),
            ]
        )
        #expect(try store.sync(fixture, to: "selection.json"))
    }

    // MARK: - Snapshot round-trip shape (§1.1)

    @Test("snapshots: canonical encoded shape for representative states")
    func snapshots() throws {
        #expect(try store.sync(SnapshotFixtures.newUser, to: "snapshots/new-user.json"))
        #expect(try store.sync(SnapshotFixtures.rich, to: "snapshots/rich.json"))
        #expect(try store.sync(SnapshotFixtures.nilOptionals, to: "snapshots/nil-optionals.json"))

        // Round-trip self-check: decode(encode(x)) == x for each.
        for snap in [SnapshotFixtures.newUser, SnapshotFixtures.rich, SnapshotFixtures.nilOptionals] {
            let data = try FixtureCoding.encoder().encode(snap)
            #expect(try FixtureCoding.decoder().decode(ProgressSnapshot.self, from: data) == snap)
        }
    }

    // MARK: - Additive merge (§1.2)

    @Test("merge: additive reconciliation never loses progress")
    func merge() throws {
        let fixture = MergeFixture(
            note: "Monotonic sets union+sort (practiced/mastered/twoCorrect/credited); "
                + "bookmarkedWordIds and selectedStacks last-write-wins (newerByUpdate); "
                + "counters max; shuffleSeed+wordQueueCursor paired from newerByUpdate; "
                + "currentStreak from later lastCompletedDate; "
                + "reviewStates per-wordId keep later lastReviewedAt.",
            cases: SnapshotFixtures.mergeCases.map { c in
                MergeCase(name: c.name, local: c.local, remote: c.remote,
                          expected: ProgressSnapshot.merge(local: c.local, remote: c.remote))
            }
        )
        #expect(try store.sync(fixture, to: "merge.json"))
    }

    // MARK: - SwiftData / Word helpers (mirror InterleavingTests)

    private func makeService() throws -> WordService {
        let schema = Schema([Word.self, UserProgress.self, DailySet.self,
                             ReviewState.self, AssessmentResult.self, PracticedSentence.self])
        let container = try ModelContainer(for: schema,
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        return WordService(modelContext: container.mainContext)
    }

    /// Stable id from the mnemonic name so shuffle/selection outputs are reproducible.
    private func mockWord(_ name: String, category: String, stack: String = "test-stack", level: Int = 1) -> Word {
        Word(id: deterministicUUID(from: name), word: name, pronunciation: "/\(name)/",
             partOfSpeech: "noun", shortDefinition: "Test", simpleDefinition: "Test",
             longDefinition: "Test", techContext: "Test", exampleSentence: "Test",
             etymology: "Test", connector: "Test", codeExampleLanguage: "swift",
             codeExampleCode: "let x = 1", stack: stack, unlockLevel: level, tags: [], category: category)
    }

    private func mockProgress(stacks: Set<String>, level: Int) -> UserProgress {
        let p = UserProgress()
        p.level = level
        p.selectedStacks = stacks
        return p
    }
}
