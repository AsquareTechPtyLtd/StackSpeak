import Testing
import Foundation
@testable import StackSpeak

@Suite("SeededRandomGenerator — determinism")
struct SeededRandomGeneratorTests {

    @Test("Same seed produces identical sequence across calls")
    func sameSeedProducesSameSequence() {
        var gen1 = SeededRandomGenerator(seed: stableHash("test-seed-v1"))
        var gen2 = SeededRandomGenerator(seed: stableHash("test-seed-v1"))

        for _ in 0..<20 {
            #expect(gen1.next() == gen2.next())
        }
    }

    @Test("Different seeds produce different sequences")
    func differentSeedsProduceDifferentSequences() {
        var gen1 = SeededRandomGenerator(seed: stableHash("seed-A"))
        var gen2 = SeededRandomGenerator(seed: stableHash("seed-B"))

        let values1 = (0..<10).map { _ in gen1.next() }
        let values2 = (0..<10).map { _ in gen2.next() }
        #expect(values1 != values2)
    }
}

@Suite("stableHash — FNV-1a stability")
struct StableHashTests {

    @Test("Hash is stable — same input always returns same value")
    func hashIsStable() {
        #expect(stableHash("idempotent") == stableHash("idempotent"))
        #expect(stableHash("") == stableHash(""))
        #expect(stableHash("abc123") == stableHash("abc123"))
    }

    @Test("Different inputs produce different hashes")
    func differentInputsAreDifferent() {
        #expect(stableHash("abc") != stableHash("abd"))
        #expect(stableHash("v1") != stableHash("v2"))
    }

    @Test("Hash is non-zero for non-empty input")
    func hashIsNonZero() {
        #expect(stableHash("anything") != 0)
    }
}
