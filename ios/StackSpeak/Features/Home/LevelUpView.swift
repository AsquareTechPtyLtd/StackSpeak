import SwiftUI
import SwiftData

struct LevelUpView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let newLevel: Int
    let userProgress: UserProgress

    @State private var selectedOptionalStacks: Set<WordStack> = []

    var levelDefinition: LevelDefinition? {
        LevelDefinition.definition(for: newLevel)
    }

    var newMandatoryStacks: [WordStack] {
        Array(WordStack.newMandatoryStacks(for: newLevel)).sorted { $0.displayName < $1.displayName }
    }

    var newOptionalStacks: [WordStack] {
        Array(WordStack.newOptionalStacks(for: newLevel)).sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: theme.spacing.xl) {
                    celebrationHeader

                    if !newMandatoryStacks.isEmpty {
                        mandatoryStacksSection
                    }

                    if !newOptionalStacks.isEmpty {
                        optionalStacksSection
                    }

                    continueButton
                }
                .padding(theme.spacing.lg)
            }
        }
    }

    private var celebrationHeader: some View {
        VStack(spacing: theme.spacing.lg) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(theme.colors.accent)

            if let levelDef = levelDefinition {
                VStack(spacing: theme.spacing.xs) {
                    Text("You're now a")
                        .font(TypographyTokens.title2)
                        .foregroundColor(theme.colors.inkMuted)

                    Text(levelDef.title)
                        .font(TypographyTokens.largeTitle)
                        .foregroundColor(theme.colors.ink)
                        .bold()

                    Text("Level \(newLevel)")
                        .font(TypographyTokens.headline)
                        .foregroundColor(theme.colors.accent)
                }
            }
        }
        .padding(.vertical, theme.spacing.xl)
    }

    private var mandatoryStacksSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text("New Core Stacks")
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.ink)

                Text("These stacks have been added to your learning path")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
            }

            VStack(spacing: theme.spacing.sm) {
                ForEach(newMandatoryStacks) { stack in
                    StackUnlockCard(stack: stack, isMandatory: true)
                }
            }
        }
    }

    private var optionalStacksSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text("New Optional Stacks")
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.ink)

                Text("Choose specializations that match your goals")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
            }

            VStack(spacing: theme.spacing.sm) {
                ForEach(newOptionalStacks) { stack in
                    StackUnlockCard(
                        stack: stack,
                        isMandatory: false,
                        isSelected: selectedOptionalStacks.contains(stack),
                        onToggle: { toggleOptionalStack(stack) }
                    )
                }
            }
        }
    }

    private var continueButton: some View {
        Button(action: saveAndContinue) {
            Text("Continue")
                .font(TypographyTokens.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.lg)
                .background(theme.colors.accent)
                .cornerRadius(12)
        }
    }

    private func toggleOptionalStack(_ stack: WordStack) {
        if selectedOptionalStacks.contains(stack) {
            selectedOptionalStacks.remove(stack)
        } else {
            selectedOptionalStacks.insert(stack)
        }
    }

    private func saveAndContinue() {
        userProgress.selectedStacks.formUnion(selectedOptionalStacks.map { $0.rawValue })
        try? modelContext.save()
        dismiss()
    }
}

struct StackUnlockCard: View {
    @Environment(\.theme) private var theme

    let stack: WordStack
    let isMandatory: Bool
    var isSelected: Bool = false
    var onToggle: (() -> Void)?

    var body: some View {
        Button(action: { onToggle?() }) {
            HStack(spacing: theme.spacing.md) {
                Image(systemName: stack.icon)
                    .font(.system(size: 20))
                    .foregroundColor(theme.colors.accent)
                    .frame(width: 32, height: 32)
                    .background(theme.colors.accentBg)
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    HStack {
                        Text(stack.displayName)
                            .font(TypographyTokens.callout.weight(.medium))
                            .foregroundColor(theme.colors.ink)

                        if isMandatory {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(theme.colors.good)
                        }
                    }

                    Text(stack.description)
                        .font(TypographyTokens.caption)
                        .foregroundColor(theme.colors.inkMuted)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if !isMandatory {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? theme.colors.accent : theme.colors.inkFaint)
                }
            }
            .padding(theme.spacing.md)
            .background(theme.colors.surface)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isMandatory)
    }
}
