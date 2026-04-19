import SwiftUI
import SwiftData
import OSLog

struct LevelUpView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let logger = Logger(subsystem: "com.stackspeak.ios", category: "LevelUp")

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
                VStack(spacing: theme.spacing.md) {
                    Text("levelUp.youAreNow")
                        .font(TypographyTokens.title3)
                        .foregroundColor(theme.colors.inkMuted)
                        .multilineTextAlignment(.center)

                    Text(levelDef.title)
                        .font(TypographyTokens.largeTitle)
                        .foregroundColor(theme.colors.ink)
                        .bold()

                    Text(levelDef.description)
                        .font(TypographyTokens.callout)
                        .foregroundColor(theme.colors.inkMuted)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.vertical, theme.spacing.xl)
    }

    private var mandatoryStacksSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text("levelUp.newCoreStacks.title")
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.ink)

                Text("levelUp.newCoreStacks.subtitle")
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
                Text("levelUp.newOptionalStacks.title")
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.ink)

                Text("levelUp.newOptionalStacks.subtitle")
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
            Text("levelUp.continue")
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.accentText)
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
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save level-up stack selection: \(error.localizedDescription, privacy: .public)")
        }
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
    }
}
