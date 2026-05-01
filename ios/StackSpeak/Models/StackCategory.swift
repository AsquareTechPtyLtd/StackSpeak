import Foundation

/// SM1 — derives a coarse category from a stack's id prefix (`basic-`,
/// `intermediate-`, `advanced-`). Lets the picker group 12+ flat stacks into
/// three scannable sections without a schema change.
enum StackCategory: String, CaseIterable, Hashable {
    case foundations
    case intermediate
    case advanced

    init(stackId: String) {
        if stackId.hasPrefix("basic-") { self = .foundations }
        else if stackId.hasPrefix("intermediate-") { self = .intermediate }
        else if stackId.hasPrefix("advanced-") { self = .advanced }
        else { self = .foundations }
    }

    var displayName: String {
        switch self {
        case .foundations:  return String(localized: "stacks.category.foundations")
        case .intermediate: return String(localized: "stacks.category.intermediate")
        case .advanced:     return String(localized: "stacks.category.advanced")
        }
    }

    var sortOrder: Int {
        switch self {
        case .foundations:  return 0
        case .intermediate: return 1
        case .advanced:     return 2
        }
    }
}

extension WordStack {
    var category: StackCategory { StackCategory(stackId: rawValue) }
}
