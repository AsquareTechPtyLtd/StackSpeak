import SwiftUI
import SwiftData
import OSLog

struct StackSelectionView: View {
    @Environment(\.theme) private var theme
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext

    private let logger = Logger(subsystem: "com.stackspeak.ios", category: "Onboarding")

    @Binding var showOnboarding: Bool

    @State private var selectedOptionalStacks: Set<WordStack> = []

    private var mandatoryStacks: [WordStack] {
        Array(WordStack.mandatoryStacks(for: 1)).sorted { $0.displayName < $1.displayName }
    }

    private var optionalStacks: [WordStack] {
        Array(WordStack.availableOptionalStacks(for: 1)).sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: theme.spacing.lg) {
                        headerSection
                        mandatoryStacksSection
                        optionalStacksSection
                    }
                    .frame(maxWidth: 720)
                    .padding(theme.spacing.lg)
                }

                continueButton
            }
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

    private var mandatoryStacksSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("onboarding.stacks.coreSection")
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.inkFaint)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, theme.spacing.sm)

            VStack(spacing: theme.spacing.sm) {
                ForEach(mandatoryStacks) { stack in
                    StackCard(stack: stack, isSelected: true, isMandatory: true, onToggle: {})
                }
            }
        }
    }

    private var optionalStacksSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("onboarding.stacks.optionalSection")
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.inkFaint)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, theme.spacing.sm)

            VStack(spacing: theme.spacing.sm) {
                ForEach(optionalStacks) { stack in
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
        Button(action: saveAndContinue) {
            Text("onboarding.stacks.continue")
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.accentText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.lg)
                .background(theme.colors.accent)
                .cornerRadius(12)
        }
        .padding(theme.spacing.lg)
        .background(theme.colors.surface)
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

        // Always include mandatory stacks — the user cannot deselect them.
        let mandatoryRawValues = Set(WordStack.mandatoryStacks(for: progress.level).map { $0.rawValue })
        let optionalRawValues = Set(selectedOptionalStacks.map { $0.rawValue })
        progress.selectedStacks = mandatoryRawValues.union(optionalRawValues)
        progress.didCompleteOnboarding = true

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save stack selection: \(error.localizedDescription, privacy: .public)")
        }
        showOnboarding = false
    }
}

struct StackCard: View {
    @Environment(\.theme) private var theme

    let stack: WordStack
    let isSelected: Bool
    let isMandatory: Bool
    let onToggle: () -> Void

    var body: some View {
        Group {
            if isMandatory {
                cardContent
            } else {
                Button(action: onToggle) { cardContent }
                    .buttonStyle(.plain)
                    .accessibilityLabel(stack.displayName)
                    .accessibilityValue(isSelected ? "selected" : "not selected")
                    .accessibilityAddTraits(.isButton)
            }
        }
    }

    private var cardContent: some View {
        HStack(spacing: theme.spacing.md) {
                Image(systemName: stack.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? theme.colors.accent : theme.colors.inkMuted)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? theme.colors.accentBg : theme.colors.surfaceAlt)
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    HStack {
                        Text(stack.displayName)
                            .font(TypographyTokens.headline)
                            .foregroundColor(theme.colors.ink)

                        if isMandatory {
                            Text("onboarding.stacks.required")
                                .font(TypographyTokens.caption)
                                .foregroundColor(theme.colors.accent)
                                .padding(.horizontal, theme.spacing.xs)
                                .padding(.vertical, 2)
                                .background(theme.colors.accentBg)
                                .cornerRadius(4)
                        }
                    }

                    Text(stack.description)
                        .font(TypographyTokens.callout)
                        .foregroundColor(theme.colors.inkMuted)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if !isMandatory {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? theme.colors.accent : theme.colors.inkFaint)
                }
            }
            .padding(theme.spacing.cardPadding(density: theme.density))
            .background(theme.colors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? theme.colors.accent : theme.colors.line, lineWidth: isSelected ? 2 : 1)
            )
    }
}

