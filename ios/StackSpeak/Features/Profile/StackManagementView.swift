import SwiftUI
import SwiftData

struct StackManagementView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var userProgressList: [UserProgress]

    @State private var selectedStacks: Set<WordStack> = []

    var userProgress: UserProgress? {
        userProgressList.first
    }

    var body: some View {
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: theme.spacing.lg) {
                    infoSection

                    mandatoryStacksSection

                    optionalStacksSection
                }
                .padding(theme.spacing.lg)
            }
        }
        .navigationTitle("Manage Stacks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveChanges()
                }
                .foregroundColor(theme.colors.accent)
            }
        }
        .onAppear {
            loadSelectedStacks()
        }
    }

    private var infoSection: some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(theme.colors.accent)

            Text("Core stacks are required and provide foundational technical vocabulary. Optional stacks can be added or removed anytime.")
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
        }
        .padding(theme.spacing.md)
        .background(theme.colors.accentBg)
        .cornerRadius(8)
    }

    private var mandatoryStacksSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Core Stacks (Unlocked)")
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.inkFaint)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, theme.spacing.sm)

            VStack(spacing: theme.spacing.sm) {
                let currentLevel = userProgress?.level ?? 1
                ForEach(Array(WordStack.mandatoryStacks(for: currentLevel)).sorted(by: { $0.displayName < $1.displayName })) { stack in
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
            Text("Optional Stacks (Available)")
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.inkFaint)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, theme.spacing.sm)

            VStack(spacing: theme.spacing.sm) {
                let currentLevel = userProgress?.level ?? 1
                ForEach(Array(WordStack.availableOptionalStacks(for: currentLevel)).sorted(by: { $0.displayName < $1.displayName })) { stack in
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

    private func loadSelectedStacks() {
        guard let progress = userProgress else { return }

        selectedStacks = WordStack.mandatoryStacks(for: progress.level)
        for stackRawValue in progress.selectedStacks {
            if let stack = WordStack(rawValue: stackRawValue), !stack.isMandatoryAtLevel {
                selectedStacks.insert(stack)
            }
        }
    }

    private func toggleStack(_ stack: WordStack) {
        if selectedStacks.contains(stack) {
            selectedStacks.remove(stack)
        } else {
            selectedStacks.insert(stack)
        }
    }

    private func saveChanges() {
        guard let progress = userProgress else { return }

        progress.selectedStacks = Set(selectedStacks.map { $0.rawValue })
        try? modelContext.save()

        dismiss()
    }
}
