import Foundation

/// Pure rules for which stacks a user persists and whether a selection is valid.
/// Lives in production code (not duplicated in tests) so `StackManagementView`
/// and its unit tests assert against the same logic.
enum StackSelectionPolicy {
    /// Minimum number of stacks a user must keep selected.
    static let minimumStacks = 3

    /// The raw stack IDs to persist for a selection.
    ///
    /// Free users always get the full mandatory set for their level unioned with
    /// their optional picks (they cannot deselect mandatory stacks). Pro users
    /// persist exactly what they selected.
    static func selectedStacks(
        level: Int,
        isPro: Bool,
        selectedMandatory: Set<WordStack>,
        selectedOptional: Set<WordStack>
    ) -> Set<String> {
        let optional = Set(selectedOptional.map(\.rawValue))
        let mandatory = isPro
            ? Set(selectedMandatory.map(\.rawValue))
            : Set(WordStack.mandatoryStacks(for: level).map(\.rawValue))
        return mandatory.union(optional)
    }

    /// Whether the current selection meets the minimum-stacks requirement.
    static func canSave(mandatoryCount: Int, optionalCount: Int) -> Bool {
        mandatoryCount + optionalCount >= minimumStacks
    }
}
