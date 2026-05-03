import Testing
import Foundation
@testable import StackSpeak

// MARK: - Helpers

/// Mirrors StackManagementView.saveChanges() for a free user — always unions mandatory + optional.
private func applyFreeUserSave(progress: UserProgress, selectedOptional: Set<String>) {
    let mandatory = Set(WordStack.mandatoryStacks(for: progress.level).map { $0.rawValue })
    progress.selectedStacks = mandatory.union(selectedOptional)
}

/// Mirrors StackManagementView.saveChanges() for a pro user — saves exactly the selection.
private func applyProUserSave(progress: UserProgress,
                               selectedMandatory: Set<String>,
                               selectedOptional: Set<String>) {
    progress.selectedStacks = selectedMandatory.union(selectedOptional)
}

/// Mirrors StackManagementView.canSave for a pro user.
private func canSavePro(mandatory: Int, optional: Int) -> Bool {
    mandatory + optional >= 3
}

// MARK: - Free user save logic

@Suite("Stack Management — free user save logic")
struct StackManagementFreeUserTests {

    @Test("Zero optional stacks → only mandatory stacks saved")
    func noOptionalSavesOnlyMandatory() {
        let progress = UserProgress()
        let mandatory = Set(WordStack.mandatoryStacks(for: 1).map { $0.rawValue })

        applyFreeUserSave(progress: progress, selectedOptional: [])

        #expect(Set(progress.selectedStacks) == mandatory)
    }

    @Test("Optional stacks are additive — mandatory stacks are never removed")
    func optionalAreAdditive() {
        let progress = UserProgress()
        let mandatory = Set(WordStack.mandatoryStacks(for: 1).map { $0.rawValue })

        applyFreeUserSave(progress: progress,
                          selectedOptional: ["basic-system-design", "basic-web"])

        let saved = Set(progress.selectedStacks)
        for m in mandatory {
            #expect(saved.contains(m), "Mandatory stack \(m) missing after free-user save")
        }
        #expect(saved.contains("basic-system-design"))
        #expect(saved.contains("basic-web"))
    }

    @Test("A known mandatory stack is always present even when not explicitly selected")
    func mandatoryAlwaysForced() {
        let progress = UserProgress()
        let mandatory = WordStack.mandatoryStacks(for: 1)
        guard let first = mandatory.first else { return }

        // Save with no optional — mandatory still forced in
        applyFreeUserSave(progress: progress, selectedOptional: [])

        #expect(Set(progress.selectedStacks).contains(first.rawValue))
    }

    @Test("Level-1 free user always satisfies minimum-3 (mandatory count >= 3)")
    func level1AlwaysSatisfiesMinimum() {
        let count = WordStack.mandatoryStacks(for: 1).count
        #expect(count >= 3)
    }
}

// MARK: - Pro user save logic

@Suite("Stack Management — pro user save logic")
struct StackManagementProUserTests {

    @Test("Pro can save with zero mandatory stacks — only optionals in result")
    func proCanExcludeAllMandatory() {
        let progress = UserProgress()
        let optionals: Set<String> = ["basic-system-design", "basic-web", "basic-api-design"]

        applyProUserSave(progress: progress, selectedMandatory: [], selectedOptional: optionals)

        #expect(Set(progress.selectedStacks) == optionals)
    }

    @Test("Pro result is exact union of selected mandatory + optional")
    func proSavesExactSelection() {
        let progress = UserProgress()
        let selMandatory: Set<String> = ["git-fundamentals", "communication-essentials"]
        let selOptional: Set<String> = ["basic-system-design"]

        applyProUserSave(progress: progress,
                         selectedMandatory: selMandatory,
                         selectedOptional: selOptional)

        #expect(Set(progress.selectedStacks) == selMandatory.union(selOptional))
        #expect(progress.selectedStacks.count == 3)
    }

    @Test("Pro: unselected mandatory stacks are NOT forced back in")
    func proMandatoryNotForcedIn() {
        let progress = UserProgress()
        let optionals: Set<String> = ["basic-system-design", "basic-web", "basic-api-design"]

        applyProUserSave(progress: progress, selectedMandatory: [], selectedOptional: optionals)

        let saved = Set(progress.selectedStacks)
        // Verify known mandatory raw IDs are absent
        #expect(!saved.contains("git-fundamentals"))
        #expect(!saved.contains("communication-essentials"))
        #expect(!saved.contains("programming-fundamentals"))
        #expect(!saved.contains("networking-essentials"))
    }

    @Test("Pro: all-mandatory selection saves only mandatory stacks")
    func proAllMandatory() {
        let progress = UserProgress()
        let selMandatory: Set<String> = ["git-fundamentals", "communication-essentials",
                                          "networking-essentials"]

        applyProUserSave(progress: progress,
                         selectedMandatory: selMandatory,
                         selectedOptional: [])

        #expect(Set(progress.selectedStacks) == selMandatory)
    }
}

// MARK: - Minimum-3 validation (pro only)

@Suite("Stack Management — minimum-3 canSave (pro)")
struct StackManagementMinimumValidationTests {

    @Test("0 stacks → cannot save")
    func zeroCannotSave() {
        #expect(canSavePro(mandatory: 0, optional: 0) == false)
    }

    @Test("1 stack → cannot save")
    func oneCannotSave() {
        #expect(canSavePro(mandatory: 1, optional: 0) == false)
        #expect(canSavePro(mandatory: 0, optional: 1) == false)
    }

    @Test("2 stacks → cannot save")
    func twoCannotSave() {
        #expect(canSavePro(mandatory: 2, optional: 0) == false)
        #expect(canSavePro(mandatory: 1, optional: 1) == false)
        #expect(canSavePro(mandatory: 0, optional: 2) == false)
    }

    @Test("Exactly 3 stacks → can save (all combinations)")
    func threeCanSave() {
        #expect(canSavePro(mandatory: 3, optional: 0) == true)
        #expect(canSavePro(mandatory: 0, optional: 3) == true)
        #expect(canSavePro(mandatory: 1, optional: 2) == true)
        #expect(canSavePro(mandatory: 2, optional: 1) == true)
    }

    @Test("4+ stacks → can save")
    func fourPlusCanSave() {
        #expect(canSavePro(mandatory: 4, optional: 0) == true)
        #expect(canSavePro(mandatory: 0, optional: 5) == true)
        #expect(canSavePro(mandatory: 10, optional: 10) == true)
    }
}

// MARK: - Pro dev toggle (UserProgress mutation)

@Suite("Pro dev toggle — UserProgress mutation")
struct ProDevToggleTests {

    @Test("Enabling toggle: isPro=true + 1-year expiry → isProActive=true")
    func enableSetsProActive() {
        let progress = UserProgress()
        #expect(progress.isProActive == false)

        progress.isPro = true
        progress.proExpiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())

        #expect(progress.isPro == true)
        #expect(progress.isProActive == true)
    }

    @Test("Disabling toggle: isPro=false + nil expiry → isProActive=false")
    func disableRevokesAccess() {
        let progress = UserProgress()
        progress.isPro = true
        progress.proExpiryDate = Date().addingTimeInterval(60 * 60 * 24 * 365)
        #expect(progress.isProActive == true)

        progress.isPro = false
        progress.proExpiryDate = nil

        #expect(progress.isPro == false)
        #expect(progress.proExpiryDate == nil)
        #expect(progress.isProActive == false)
    }

    @Test("Toggle on then off: leaves user with no pro access")
    func toggleOnThenOff() {
        let progress = UserProgress()

        progress.isPro = true
        progress.proExpiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
        #expect(progress.isProActive == true)

        progress.isPro = false
        progress.proExpiryDate = nil
        #expect(progress.isProActive == false)
    }

    @Test("Toggle off then on: restores pro access")
    func toggleOffThenOn() {
        let progress = UserProgress()
        #expect(progress.isProActive == false)

        progress.isPro = true
        progress.proExpiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
        #expect(progress.isProActive == true)
    }

    @Test("1-year expiry is strictly in the future")
    func oneYearExpiryIsFuture() {
        let expiry = Calendar.current.date(byAdding: .year, value: 1, to: Date())
        #expect(expiry != nil)
        #expect(expiry! > Date())
    }
}
