import SwiftUI
import SwiftData
import OSLog

/// SM3 — three popular optional stacks come pre-selected on first launch so
/// new users don't have to make decisions before they've seen the product.
/// Easy to deselect.
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

    private var optionalStacksByCategory: [(StackCategory, [WordStack])] {
        let stacks = Array(WordStack.availableOptionalStacks(for: 1))
        return Dictionary(grouping: stacks, by: \.category)
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
                    .frame(maxWidth: 720)
                    .padding(theme.spacing.lg)
                }

                continueButton
            }
        }
        .onAppear { applySmartDefaultsOnce() }
        .sheet(isPresented: $showProSheet) {
            ProGateSheet()
                .presentationDetents([.medium])
        }
        .alert("saveError.title", isPresented: .constant(saveError != nil), presenting: saveError) { _ in
            Button("common.ok") { saveError = nil }
        } message: { error in
            Text(String(format: String(localized: "saveError.stackSelection.format"),
                        error.localizedDescription))
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("onboarding.stacks.title")
                .font(TypographyTokens.title1)
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
                        .padding(.vertical, 4)
                        .background(theme.colors.accentBg)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, theme.spacing.sm)

            VStack(spacing: theme.spacing.sm) {
                ForEach(mandatoryStacks) { stack in
                    StackCard(stack: stack, isSelected: true, isMandatory: false,
                              isLocked: true, onToggle: {})
                }
            }
        }
    }

    private func optionalSection(category: StackCategory, stacks: [WordStack]) -> some View {
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
                        isMandatory: false,
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

/// Shared stack-row component used by Stack Selection (onboarding), Stack
/// Management (settings), and the Level-Up sheet's optional picker.
struct StackCard: View {
    @Environment(\.theme) private var theme

    let stack: WordStack
    let isSelected: Bool
    let isMandatory: Bool
    let isLocked: Bool
    let onToggle: () -> Void

    init(stack: WordStack, isSelected: Bool, isMandatory: Bool,
         isLocked: Bool = false, onToggle: @escaping () -> Void) {
        self.stack = stack
        self.isSelected = isSelected
        self.isMandatory = isMandatory
        self.isLocked = isLocked
        self.onToggle = onToggle
    }

    var body: some View {
        Group {
            if isMandatory || isLocked {
                cardContent
                    .accessibilityLabel(stack.displayName)
                    .accessibilityHint(isLocked ? String(localized: "stacks.locked.a11yHint") : "")
            } else {
                Button(action: onToggle) { cardContent }
                    .buttonStyle(.plain)
                    .accessibilityLabel(stack.displayName)
                    .accessibilityValue(isSelected ? "selected" : "not selected")
                    .accessibilityAddTraits(.isButton)
            }
        }
    }

    private enum CardState { case locked, active, idle }

    private var cardState: CardState {
        if isLocked { return .locked }
        return isSelected ? .active : .idle
    }

    private var cardContent: some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: stack.icon)
                .font(.system(.title2))
                .foregroundColor(iconForeground)
                .frame(width: 36, height: 36)
                .background(iconBackground)
                .clipShape(.rect(cornerRadius: RadiusTokens.inline))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: theme.spacing.xs) {
                    Text(stack.displayName)
                        .font(TypographyTokens.headline)
                        .foregroundColor(isLocked ? theme.colors.inkMuted : theme.colors.ink)
                    if isMandatory {
                        Text("onboarding.stacks.required")
                            .font(TypographyTokens.caption)
                            .foregroundColor(theme.colors.inkMuted)
                    }
                }

                Text(stack.description)
                    .font(TypographyTokens.footnote)
                    .foregroundColor(theme.colors.inkMuted)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            if !isMandatory {
                Image(systemName: cardState == .active ? "checkmark.circle.fill" : "circle")
                    .font(.system(.title2))
                    .foregroundColor(cardState == .active ? theme.colors.accent : theme.colors.inkFaint)
            }
        }
        .padding(theme.spacing.cardPadding)
        .background(cardState == .active ? theme.colors.accentBg : theme.colors.surface)
        .clipShape(.rect(cornerRadius: RadiusTokens.card))
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .stroke(
                    cardState == .active ? theme.colors.accent : theme.colors.line,
                    lineWidth: cardState == .active ? 1.5 : 0.5
                )
        )
    }

    private var iconForeground: Color {
        switch cardState {
        case .locked: return theme.colors.inkFaint
        case .active: return theme.colors.accent
        case .idle:   return theme.colors.inkMuted
        }
    }

    private var iconBackground: Color {
        cardState == .active ? theme.colors.accentBg : theme.colors.surfaceAlt
    }
}
