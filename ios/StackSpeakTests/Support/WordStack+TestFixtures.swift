import Foundation
@testable import StackSpeak

/// Test fixtures for WordStack used in test cases.
/// These map to actual stack IDs in shared/words-index.json.
extension WordStack {
    static let basicProgramming = WordStack(rawValue: "basic-programming")
    static let basicWeb = WordStack(rawValue: "basic-web")
    static let intermediateCodeQuality = WordStack(rawValue: "intermediate-code-quality")
    static let advancedAlgorithms = WordStack(rawValue: "advanced-algorithms")
    static let basicSystemDesign = WordStack(rawValue: "basic-system-design")
    static let basicGit = WordStack(rawValue: "basic-git")
    static let basicNetworking = WordStack(rawValue: "basic-networking")
}
