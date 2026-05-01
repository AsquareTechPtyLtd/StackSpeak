import Testing
import Foundation
@testable import StackSpeak

/// Per the council's follow-up action #2 — locks down the Feynman stage
/// transition table so a future edit can't silently break the flow,
/// especially the coming-soon branch that skips the connector stage.
@Suite("FeynmanStage transitions")
struct FeynmanStageTransitionTests {

    // MARK: - Forward — fully-authored words

    @Test("simple → technical")
    func simpleAdvances() {
        #expect(FeynmanStage.simple.next(isComingSoon: false) == .technical)
    }

    @Test("technical → explain")
    func technicalAdvances() {
        #expect(FeynmanStage.technical.next(isComingSoon: false) == .explain)
    }

    @Test("explain → connector for fully-authored words")
    func explainAdvancesToConnector() {
        #expect(FeynmanStage.explain.next(isComingSoon: false) == .connector)
    }

    @Test("connector → done")
    func connectorAdvances() {
        #expect(FeynmanStage.connector.next(isComingSoon: false) == .done)
    }

    @Test("done is terminal — no forward transition")
    func doneIsTerminal() {
        #expect(FeynmanStage.done.next(isComingSoon: false) == nil)
    }

    // MARK: - Forward — coming-soon words

    @Test("Coming-soon: explain → done (connector is skipped)")
    func explainSkipsConnectorForComingSoon() {
        #expect(FeynmanStage.explain.next(isComingSoon: true) == .done)
    }

    @Test("Coming-soon: connector still advances to done if reached")
    func connectorStillAdvances() {
        // This case shouldn't normally occur (connector unreachable forward),
        // but keep the table coherent for back-navigation regressions.
        #expect(FeynmanStage.connector.next(isComingSoon: true) == .done)
    }

    @Test("Coming-soon: done is terminal")
    func comingSoonDoneTerminal() {
        #expect(FeynmanStage.done.next(isComingSoon: true) == nil)
    }

    // MARK: - Backward — fully-authored words

    @Test("simple has no previous stage")
    func simpleIsRoot() {
        #expect(FeynmanStage.simple.previous(isComingSoon: false) == nil)
    }

    @Test("technical → simple")
    func technicalRetreats() {
        #expect(FeynmanStage.technical.previous(isComingSoon: false) == .simple)
    }

    @Test("explain → technical")
    func explainRetreats() {
        #expect(FeynmanStage.explain.previous(isComingSoon: false) == .technical)
    }

    @Test("connector → explain")
    func connectorRetreats() {
        #expect(FeynmanStage.connector.previous(isComingSoon: false) == .explain)
    }

    @Test("done → connector for fully-authored words")
    func doneRetreatsToConnector() {
        #expect(FeynmanStage.done.previous(isComingSoon: false) == .connector)
    }

    // MARK: - Backward — coming-soon words

    @Test("Coming-soon: done → explain (connector still skipped backward)")
    func doneRetreatsPastSkippedConnector() {
        #expect(FeynmanStage.done.previous(isComingSoon: true) == .explain)
    }

    @Test("Coming-soon: simple has no previous stage")
    func comingSoonSimpleIsRoot() {
        #expect(FeynmanStage.simple.previous(isComingSoon: true) == nil)
    }

    // MARK: - Round-trip invariants

    @Test("Round trip: every non-terminal stage's next.previous returns to itself (fully authored)")
    func roundTripFullyAuthored() {
        for stage in FeynmanStage.allCases where stage != .done {
            guard let next = stage.next(isComingSoon: false) else { continue }
            #expect(next.previous(isComingSoon: false) == stage,
                    "next then previous from \(stage) returned \(next.previous(isComingSoon: false) as Any) instead of \(stage)")
        }
    }

    @Test("Round trip: every reachable stage's next.previous returns to itself (coming soon)")
    func roundTripComingSoon() {
        // .simple, .technical, .explain are the reachable forward stages.
        // explain.next == .done, .done.previous == .explain, so it round-trips
        // correctly. .connector is unreachable forward in coming-soon mode.
        for stage in [FeynmanStage.simple, .technical, .explain] {
            guard let next = stage.next(isComingSoon: true) else { continue }
            #expect(next.previous(isComingSoon: true) == stage,
                    "coming-soon next then previous from \(stage) didn't round-trip")
        }
    }
}
