import SwiftUI
import SwiftData
import OSLog

/// SM1 — optional stacks grouped by category (Foundations / Intermediate /
/// Advanced) so the picker doesn't read as one long flat list.
struct StackManagementView: View {
    @Environment(\.theme) private var theme
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let logger = Logger(subsystem: "com.stackspeak.ios", category: "Settings")

    @State private var selectedOptionalStacks: Set<WordStack> = []
    @State private var saveError: Error?
    @State private var saveSuccessTrigger = 0

    private var currentLevel: Int { userProgress?.level ?? 1 }

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
                    .foregroundColor(theme.colors.accent)
            }
        }
        .onAppear { loadSelectedStacks() }
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

            Text("stacks.info")
                .font(TypographyTokens.footnote)
                .foregroundColor(theme.colors.inkMuted)
        }
        .padding(theme.spacing.md)
        .background(theme.colors.accentBg)
        .clipShape(.rect(cornerRadius: RadiusTokens.inline))
    }

    private var coreSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text("stacks.section.core")
                .font(TypographyTokens.subheadline.weight(.medium))
                .foregroundColor(theme.colors.inkMuted)
                .padding(.horizontal, theme.spacing.sm)

            VStack(spacing: theme.spacing.sm) {
                ForEach(mandatoryStacks) { stack in
                    StackCard(stack: stack, isSelected: true, isMandatory: true, onToggle: {})
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

    private func loadSelectedStacks() {
        guard let progress = userProgress else { return }
        selectedOptionalStacks = Set(
            progress.selectedStacks.compactMap { WordStack(rawValue: $0) }.filter { !$0.isMandatory }
        )
    }

    private func toggleStack(_ stack: WordStack) {
        if selectedOptionalStacks.contains(stack) {
            selectedOptionalStacks.remove(stack)
        } else {
            selectedOptionalStacks.insert(stack)
        }
    }

    private func saveChanges() {
        guard let progress = userProgress else { return }
        let mandatory = Set(WordStack.mandatoryStacks(for: progress.level).map { $0.rawValue })
        let optional  = Set(selectedOptionalStacks.map { $0.rawValue })
        progress.selectedStacks = mandatory.union(optional)
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
