import SwiftUI
import SwiftData
import OSLog

/// Lets users manage which stacks feed their daily words. Optional stacks are
/// grouped by category; pro users can also deselect mandatory stacks.
struct StackManagementView: View {
    @Environment(\.theme) private var theme
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let logger = Logger(category: "Settings")

    @State private var selectedOptionalStacks: Set<WordStack> = []
    @State private var selectedMandatoryStacks: Set<WordStack> = []
    @State private var saveError: Error?
    @State private var saveSuccessTrigger = 0
    @State private var showProSheet = false

    private var currentLevel: Int { userProgress?.level ?? 1 }
    private var isPro: Bool { userProgress?.isProActive ?? false }

    private var mandatoryStacks: [WordStack] {
        Array(WordStack.mandatoryStacks(for: currentLevel))
            .sorted(by: { $0.displayName < $1.displayName })
    }

    private var optionalStacksByCategory: [(StackCategory, [WordStack])] {
        let stacks = Array(WordStack.availableOptionalStacks(for: currentLevel))
        return Dictionary(grouping: stacks, by: \.category)
            .map { ($0.key, $0.value.sorted(by: { $0.displayName < $1.displayName })) }
            .sorted { $0.0.sortOrder < $1.0.sortOrder }
    }

    private var canSave: Bool {
        StackSelectionPolicy.canSave(
            mandatoryCount: isPro ? selectedMandatoryStacks.count : mandatoryStacks.count,
            optionalCount: selectedOptionalStacks.count
        )
    }

    var body: some View {
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: theme.spacing.xl) {
                    infoBanner
                    coreSection
                    ForEach(optionalStacksByCategory, id: \.0) { category, stacks in
                        optionalSection(category: category, stacks: stacks)
                    }
                    if isPro && !canSave {
                        minimumStacksWarning
                    }
                }
                .frame(maxWidth: 720)
                .padding(theme.spacing.lg)
            }
        }
        .navigationTitle("stacks.navTitle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("stacks.save", action: saveChanges)
                    .foregroundColor(canSave ? theme.colors.accent : theme.colors.inkFaint)
                    .disabled(!canSave)
            }
        }
        .onAppear { loadSelectedStacks() }
        .sheet(isPresented: $showProSheet) {
            ProGateSheet()
                .presentationDetents([.medium])
        }
        .sensoryFeedback(.success, trigger: saveSuccessTrigger)
        .alert("saveError.title", isPresented: .constant(saveError != nil), presenting: saveError) { _ in
            Button("common.ok") { saveError = nil }
        } message: { error in
            Text(String(format: String(localized: "saveError.stackManagement.format"),
                        error.localizedDescription))
        }
    }

    private var infoBanner: some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: "info.circle")
                .foregroundColor(theme.colors.accent)
                .accessibilityHidden(true)

            Text(isPro ? "stacks.info.pro" : "stacks.info")
                .font(TypographyTokens.footnote)
                .foregroundColor(theme.colors.inkMuted)
        }
        .padding(theme.spacing.md)
        .background(theme.colors.accentBg)
        .clipShape(.rect(cornerRadius: RadiusTokens.inline))
    }

    private var coreSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack {
                Text("stacks.section.core")
                    .font(TypographyTokens.subheadline.weight(.medium))
                    .foregroundColor(theme.colors.inkMuted)
                Spacer()
                if !isPro {
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
            }
            .padding(.horizontal, theme.spacing.sm)

            VStack(spacing: theme.spacing.sm) {
                ForEach(mandatoryStacks) { stack in
                    StackCard(
                        stack: stack,
                        isSelected: isPro ? selectedMandatoryStacks.contains(stack) : true,
                        isLocked: !isPro,
                        onToggle: { toggleMandatoryStack(stack) }
                    )
                }
            }
        }
    }

    private var minimumStacksWarning: some View {
        Text("stacks.minimumStacks")
            .font(TypographyTokens.footnote)
            .foregroundColor(theme.colors.bad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, theme.spacing.sm)
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
                        onToggle: { toggleStack(stack) }
                    )
                }
            }
        }
    }

    private func loadSelectedStacks() {
        guard let progress = userProgress else { return }
        let selected = Set(progress.selectedStacks.compactMap { WordStack(rawValue: $0) })
        let mandatorySet = Set(mandatoryStacks)
        if isPro {
            selectedMandatoryStacks = selected.intersection(mandatorySet)
        }
        selectedOptionalStacks = selected.filter { !$0.isMandatory }
    }

    private func toggleStack(_ stack: WordStack) {
        if selectedOptionalStacks.contains(stack) {
            selectedOptionalStacks.remove(stack)
        } else {
            selectedOptionalStacks.insert(stack)
        }
    }

    private func toggleMandatoryStack(_ stack: WordStack) {
        guard isPro else { return }
        if selectedMandatoryStacks.contains(stack) {
            selectedMandatoryStacks.remove(stack)
        } else {
            selectedMandatoryStacks.insert(stack)
        }
    }

    private func saveChanges() {
        guard let progress = userProgress, canSave else { return }
        progress.selectedStacks = StackSelectionPolicy.selectedStacks(
            level: progress.level,
            isPro: isPro,
            selectedMandatory: selectedMandatoryStacks,
            selectedOptional: selectedOptionalStacks
        )
        do {
            try modelContext.save()
            saveSuccessTrigger &+= 1
            dismiss()
        } catch {
            logger.error("Failed to save stack changes: \(error.localizedDescription, privacy: .public)")
            saveError = error
        }
    }
}

#Preview("Stack Management - Light") {
    NavigationStack {
        StackManagementView()
            .withTheme(ThemeManager())
    }
}

#Preview("Stack Management - Dark") {
    NavigationStack {
        StackManagementView()
            .withTheme(ThemeManager())
            .preferredColorScheme(.dark)
    }
}
