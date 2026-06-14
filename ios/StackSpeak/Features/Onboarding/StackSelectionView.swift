import SwiftUI
import SwiftData
import OSLog

/// Three popular optional stacks come pre-selected on first launch so new users
/// don't have to make decisions before they've seen the product. Easy to deselect.
struct StackSelectionView: View {
    @Environment(\.theme) private var theme
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext

    private let logger = Logger(category: "Onboarding")

    @Binding var showOnboarding: Bool

    @State private var selectedOptionalStacks: Set<WordStack> = []
    @State private var saveError: Error?
    @State private var didApplyDefaults = false
    @State private var showProSheet = false

    /// Smart defaults applied on first appearance. Three frequently-relevant
    /// stacks for software engineers; the user can deselect any of them.
    private static let smartDefaultIds = ["basic-api-design", "basic-testing", "basic-system-design"]

    private var mandatoryStacks: [WordStack] {
        WordStack.mandatoryStacks(for: 1).sorted(by: { $0.displayName < $1.displayName })
    }

    private var optionalStacksByCategory: [(StackTopic, [WordStack])] {
        let stacks = Array(WordStack.availableOptionalStacks(for: 1))
        return Dictionary(grouping: stacks, by: \.topic)
            .map { ($0.key, $0.value.sorted(by: { $0.displayName < $1.displayName })) }
            .sorted { $0.0.sortOrder < $1.0.sortOrder }
    }

    var body: some View {
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing.xl) {
                        headerSection
                        coreSection
                        ForEach(optionalStacksByCategory, id: \.0) { category, stacks in
                            optionalSection(category: category, stacks: stacks)
                        }
                    }
                    .frame(maxWidth: LayoutTokens.contentMaxWidth)
                    .padding(theme.spacing.lg)
                }

                continueButton
            }
        }
        .onAppear { applySmartDefaultsOnce() }
        .sheet(isPresented: $showProSheet) {
            ProGateSheet()
        }
        .alert("saveError.title",
               isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } }),
               presenting: saveError) { _ in
            Button("common.ok") { saveError = nil }
        } message: { error in
            Text(String(format: String(localized: "saveError.stackSelection.format"),
                        error.localizedDescription))
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            // Brand serif extends the onboarding glyph language onto its
            // final page instead of dropping to token-painted Inter.
            Text("onboarding.stacks.title")
                .font(TypographyTokens.title1Serif)
                .foregroundColor(theme.colors.ink)

            Text("onboarding.stacks.description")
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var coreSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack {
                Text("onboarding.stacks.coreSection")
                    .font(TypographyTokens.subheadline.weight(.medium))
                    .foregroundColor(theme.colors.inkMuted)
                Spacer()
                Button { showProSheet = true } label: {
                    Text("stacks.getPro")
                        .font(TypographyTokens.caption.weight(.semibold))
                        .foregroundColor(theme.colors.accent)
                        .padding(.horizontal, theme.spacing.sm)
                        .padding(.vertical, theme.spacing.xs)
                        .background(theme.colors.accentBg)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, theme.spacing.sm)

            VStack(spacing: theme.spacing.sm) {
                ForEach(mandatoryStacks) { stack in
                    StackCard(stack: stack, isSelected: true,
                              isLocked: true, onToggle: {})
                }
            }
        }
    }

    private func optionalSection(category: StackTopic, stacks: [WordStack]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text(category.displayName)
                .font(TypographyTokens.subheadline.weight(.medium))
                .foregroundColor(theme.colors.inkMuted)
                .padding(.horizontal, theme.spacing.sm)

            VStack(spacing: theme.spacing.sm) {
                ForEach(stacks) { stack in
                    StackCard(
                        stack: stack,
                        isSelected: selectedOptionalStacks.contains(stack),
                        onToggle: { toggleStack(stack) }
                    )
                }
            }
        }
    }

    private var continueButton: some View {
        PrimaryCTAButton("onboarding.stacks.continue") {
            saveAndContinue()
        }
        .padding(theme.spacing.lg)
        .background(theme.colors.bg)
    }

    private func applySmartDefaultsOnce() {
        guard !didApplyDefaults else { return }
        didApplyDefaults = true

        let availableOptional = WordStack.availableOptionalStacks(for: 1)
        for id in Self.smartDefaultIds {
            let stack = WordStack(rawValue: id)
            if availableOptional.contains(stack) {
                selectedOptionalStacks.insert(stack)
            }
        }
    }

    private func toggleStack(_ stack: WordStack) {
        if selectedOptionalStacks.contains(stack) {
            selectedOptionalStacks.remove(stack)
        } else {
            selectedOptionalStacks.insert(stack)
        }
    }

    private func saveAndContinue() {
        guard let progress = userProgress else { return }

        let mandatoryRawValues = Set(WordStack.mandatoryStacks(for: progress.level).map { $0.rawValue })
        let optionalRawValues = Set(selectedOptionalStacks.map { $0.rawValue })
        progress.selectedStacks = mandatoryRawValues.union(optionalRawValues)
        progress.didCompleteOnboarding = true

        do {
            try modelContext.save()
            showOnboarding = false
        } catch {
            logger.error("Failed to save stack selection: \(error.localizedDescription, privacy: .public)")
            saveError = error
        }
    }
}

// MARK: - Previews

#Preview("Stack Selection — Light") {
    StackSelectionView(showOnboarding: .constant(true))
        .modelContainer(for: [Word.self, UserProgress.self], inMemory: true)
        .environment(\.userProgress, UserProgress())
        .withTheme(ThemeManager())
}

#Preview("Stack Selection — Dark") {
    StackSelectionView(showOnboarding: .constant(true))
        .modelContainer(for: [Word.self, UserProgress.self], inMemory: true)
        .environment(\.userProgress, UserProgress())
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
