import Foundation

/// Topical grouping for word stacks (architecture, data, security, …). Sourced
/// from `StackDefinition.category` in words-index.json and used to organize the
/// stack picker by subject. Open/tolerant: an unknown or missing value decodes
/// to `.other` so new topics never break loading.
enum StackTopic: String, CaseIterable, Codable, Hashable {
    case foundations
    case languages
    case architecture
    case data
    case aiml = "ai-ml"
    case cloud
    case devopsSre = "devops-sre"
    case security
    case testing
    case people
    case enterprise
    case other

    var displayName: String {
        switch self {
        case .foundations:  return String(localized: "stacks.topic.foundations")
        case .languages:    return String(localized: "stacks.topic.languages")
        case .architecture: return String(localized: "stacks.topic.architecture")
        case .data:         return String(localized: "stacks.topic.data")
        case .aiml:         return String(localized: "stacks.topic.aiml")
        case .cloud:        return String(localized: "stacks.topic.cloud")
        case .devopsSre:    return String(localized: "stacks.topic.devopsSre")
        case .security:     return String(localized: "stacks.topic.security")
        case .testing:      return String(localized: "stacks.topic.testing")
        case .people:       return String(localized: "stacks.topic.people")
        case .enterprise:   return String(localized: "stacks.topic.enterprise")
        case .other:        return String(localized: "stacks.topic.other")
        }
    }

    /// Display order for the picker sections.
    var sortOrder: Int {
        switch self {
        case .foundations:  return 0
        case .languages:    return 1
        case .architecture: return 2
        case .data:         return 3
        case .aiml:         return 4
        case .cloud:        return 5
        case .devopsSre:    return 6
        case .security:     return 7
        case .testing:      return 8
        case .people:       return 9
        case .enterprise:   return 10
        case .other:        return 11
        }
    }
}

extension WordStack {
    /// Topical grouping for this stack (via StackRegistry); `.other` if unknown.
    var topic: StackTopic { definition?.category ?? .other }
}
