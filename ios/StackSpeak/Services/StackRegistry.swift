import Foundation
import OSLog

private let logger = Logger(category: "StackRegistry")

final class StackRegistry: @unchecked Sendable {
    static let shared = StackRegistry()

    let allStacks: [StackDefinition]
    let loadError: (any Error)?
    private let stacksById: [String: StackDefinition]

    private init() {
        guard let url = Bundle.main.url(forResource: "words-index", withExtension: "json") else {
            let error = NSError(domain: "com.stackspeak.ios", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "words-index.json not found in bundle"
            ])
            self.allStacks = []
            self.stacksById = [:]
            self.loadError = error
            logger.error("Failed to locate words-index.json in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let index = try JSONDecoder().decode(StacksIndex.self, from: data)
            self.allStacks = index.stacks
            self.stacksById = Dictionary(uniqueKeysWithValues: index.stacks.map { ($0.id, $0) })
            self.loadError = nil
            logger.info("Loaded \(index.stacks.count) stacks from words-index.json")
        } catch {
            self.allStacks = []
            self.stacksById = [:]
            self.loadError = error
            logger.error("Failed to load words-index.json: \(error.localizedDescription)")
        }
    }

    func stack(for id: String) -> StackDefinition? {
        stacksById[id]
    }

    func mandatoryStacks(for level: Int) -> [StackDefinition] {
        allStacks.filter { $0.isMandatory && $0.minimumLevel <= level }
    }

    func newMandatoryStacks(for level: Int) -> [StackDefinition] {
        allStacks.filter { $0.isMandatory && $0.minimumLevel == level }
    }

    func availableOptionalStacks(for level: Int) -> [StackDefinition] {
        allStacks.filter { !$0.isMandatory && $0.minimumLevel <= level }
    }

    func newOptionalStacks(for level: Int) -> [StackDefinition] {
        allStacks.filter { !$0.isMandatory && $0.minimumLevel == level }
    }
}
