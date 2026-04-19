import Foundation

/// Lightweight identifier for word stacks.
/// Metadata and filtering logic lives in StackRegistry, which loads from words-index.json.
struct WordStack: RawRepresentable, Codable, Hashable, Identifiable {
    let rawValue: String

    var id: String { rawValue }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    // MARK: - Helper methods (delegated to StackRegistry)

    static var allCases: [WordStack] {
        StackRegistry.shared.allStacks.map { WordStack(rawValue: $0.id) }
    }

    static func mandatoryStacks(for level: Int) -> Set<WordStack> {
        Set(StackRegistry.shared.mandatoryStacks(for: level).map { WordStack(rawValue: $0.id) })
    }

    static func newMandatoryStacks(for level: Int) -> Set<WordStack> {
        Set(StackRegistry.shared.newMandatoryStacks(for: level).map { WordStack(rawValue: $0.id) })
    }

    static func availableOptionalStacks(for level: Int) -> Set<WordStack> {
        Set(StackRegistry.shared.availableOptionalStacks(for: level).map { WordStack(rawValue: $0.id) })
    }

    static func newOptionalStacks(for level: Int) -> Set<WordStack> {
        Set(StackRegistry.shared.newOptionalStacks(for: level).map { WordStack(rawValue: $0.id) })
    }

    // MARK: - Metadata access (via StackRegistry)

    var definition: StackDefinition? {
        StackRegistry.shared.stack(for: rawValue)
    }

    var displayName: String {
        definition?.name ?? rawValue
    }

    var description: String {
        definition?.description ?? ""
    }

    var icon: String {
        definition?.icon ?? "questionmark.circle"
    }

    var minimumLevel: Int {
        definition?.minimumLevel ?? 1
    }

    var isMandatory: Bool {
        definition?.isMandatory ?? false
    }
}
