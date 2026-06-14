import Foundation
@testable import StackSpeak

// Support for the cross-platform golden fixtures written to `shared/test-fixtures/`.
// These are the *executable contract* Android must reproduce value-for-value
// (see `.planning/android-app-plan-2026-06-14.md` §Part 1). Everything here is
// pure/deterministic — no `Date()`, no RNG — so the bytes are stable across runs.

// MARK: - Canonical coding

enum FixtureCoding {
    /// Matches the backend's date strategy (`.iso8601`, no fractional seconds —
    /// the real wire contract) and adds sorted keys + pretty printing so the
    /// committed files diff cleanly. Field *order* isn't a functional requirement;
    /// the date format and key omission (nil → absent) are.
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }

    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

// MARK: - Deterministic clock

/// Fixed timestamps so SM-2 due dates / snapshot `updatedAt` are reproducible.
enum FixtureClock {
    /// 2026-01-01T00:00:00Z — whole seconds, so `.iso8601` emits no fractional part.
    static let epoch = Date(timeIntervalSince1970: 1_767_225_600)
    static func plusDays(_ n: Int) -> Date { epoch.addingTimeInterval(Double(n) * 86_400) }

    /// UTC Gregorian calendar — day arithmetic must not depend on the test host's zone.
    static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
}

// MARK: - Fixture file store

/// Writes fixtures on first run (or when `GENERATE_FIXTURES=1`), and validates
/// against the committed bytes otherwise — so drift in any determinism-critical
/// code surfaces as a failing test until the fixtures are intentionally regenerated.
struct FixtureStore {
    let root: URL
    let forceWrite: Bool

    init(file: StaticString = #filePath) {
        // file = <repo>/ios/StackSpeakTests/Fixtures/FixtureSupport.swift
        var url = URL(fileURLWithPath: "\(file)")
        url.deleteLastPathComponent() // Fixtures
        url.deleteLastPathComponent() // StackSpeakTests
        url.deleteLastPathComponent() // ios
        url.deleteLastPathComponent() // <repo>
        self.root = url.appendingPathComponent("shared/test-fixtures", isDirectory: true)
        self.forceWrite = ProcessInfo.processInfo.environment["GENERATE_FIXTURES"] == "1"
    }

    /// Returns true when the on-disk fixture matches `data` (or was just written).
    @discardableResult
    func sync(_ data: Data, to relativePath: String) throws -> Bool {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        if forceWrite || !FileManager.default.fileExists(atPath: url.path) {
            try data.write(to: url)
            return true
        }
        return (try Data(contentsOf: url)) == data
    }

    /// Encodes `value` canonically (trailing newline for POSIX-friendly files) and syncs it.
    @discardableResult
    func sync<T: Encodable>(_ value: T, to relativePath: String) throws -> Bool {
        var data = try FixtureCoding.encoder().encode(value)
        data.append(0x0A)
        return try sync(data, to: relativePath)
    }
}

// MARK: - Fixture DTOs (the JSON shapes both platforms assert against)

/// UInt64 values are emitted as decimal **strings** — JSON numbers can't safely
/// hold a u64, and Kotlin reads them back as `ULong`.
struct PrimitivesFixture: Encodable {
    struct HashCase: Encodable { let input: String; let stableHash: String }
    struct UUIDCase: Encodable { let input: String; let uuid: String }
    struct RNGCase: Encodable { let seedString: String; let seed: String; let sequence: [String] }
    let note: String
    let stableHash: [HashCase]
    let deterministicUUID: [UUIDCase]
    let seededRandom: [RNGCase]
}

struct SM2State: Encodable {
    let easinessFactor: Double
    let interval: Int
    let repetitions: Int
    let dueDate: Date
    let lastReviewedAt: Date?
}

struct SM2Sequence: Encodable {
    let name: String
    let wordId: String
    let appliedAt: Date
    let grades: [Int]
    let initial: SM2State
    let afterEachGrade: [SM2State]
}

struct SM2Fixture: Encodable {
    let note: String
    let calendar: String
    let sequences: [SM2Sequence]
}

struct ShuffleCase: Encodable {
    let name: String
    let seed: String
    let inputIds: [String]
    let outputIds: [String]
}
struct ShuffleFixture: Encodable { let note: String; let cases: [ShuffleCase] }

struct SelectionCase: Encodable {
    let name: String
    let level: Int
    let selectedStacks: [String]
    let masteredIds: [String]
    let startCursor: Int
    let count: Int
    let inputWordIds: [String]
    let selectedWordIds: [String]
    let nextCursor: Int
}
struct SelectionFixture: Encodable { let note: String; let cases: [SelectionCase] }

struct MergeCase: Encodable {
    let name: String
    let local: ProgressSnapshot
    let remote: ProgressSnapshot
    let expected: ProgressSnapshot
}
struct MergeFixture: Encodable { let note: String; let cases: [MergeCase] }
