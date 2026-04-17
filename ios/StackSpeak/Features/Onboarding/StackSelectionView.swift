import SwiftUI
import SwiftData

struct StackSelectionView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Query private var userProgressList: [UserProgress]

    @Binding var showOnboarding: Bool

    @State private var selectedStacks: Set<WordStack> = []

    var userProgress: UserProgress? {
        userProgressList.first
    }

    var body: some View {
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection

                ScrollView {
                    VStack(spacing: theme.spacing.lg) {
                        mandatoryStacksSection
                        optionalStacksSection
                    }
                    .padding(theme.spacing.lg)
                }

                continueButton
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Choose Your Learning Path")
                .font(TypographyTokens.title1)
                .foregroundColor(theme.colors.ink)

            Text("Core stacks are essential fundamentals. Add optional stacks to specialize your learning.")
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.inkMuted)
        }
        .padding(theme.spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.surface)
    }

    private var mandatoryStacksSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Core Stacks (Level 1)")
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.inkFaint)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, theme.spacing.sm)

            VStack(spacing: theme.spacing.sm) {
                ForEach(Array(WordStack.mandatoryStacks(for: 1)).sorted(by: { $0.displayName < $1.displayName })) { stack in
                    StackCard(
                        stack: stack,
                        isSelected: true,
                        isMandatory: true,
                        onToggle: {}
                    )
                }
            }
        }
    }

    private var optionalStacksSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Optional Stacks (Level 1)")
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.inkFaint)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, theme.spacing.sm)

            VStack(spacing: theme.spacing.sm) {
                ForEach(Array(WordStack.availableOptionalStacks(for: 1)).sorted(by: { $0.displayName < $1.displayName })) { stack in
                    StackCard(
                        stack: stack,
                        isSelected: selectedStacks.contains(stack),
                        isMandatory: false,
                        onToggle: { toggleStack(stack) }
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
        .padding(theme.spacing.lg)
        .background(theme.colors.surface)
    }

    private func toggleStack(_ stack: WordStack) {
        if selectedStacks.contains(stack) {
            selectedStacks.remove(stack)
        } else {
            selectedStacks.insert(stack)
        }
    }

    private func saveAndContinue() {
        guard let progress = userProgress else { return }

        progress.selectedStacks = Set(selectedStacks.map { $0.rawValue })
        try? modelContext.save()

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
        Button(action: isMandatory ? {} : onToggle) {
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
                            Text("REQUIRED")
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
        .buttonStyle(.plain)
        .disabled(isMandatory)
    }
}
