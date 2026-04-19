import SwiftUI
import SwiftData
import OSLog

struct StackManagementView: View {
    @Environment(\.theme) private var theme
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let logger = Logger(subsystem: "com.stackspeak.ios", category: "Settings")

    @State private var selectedOptionalStacks: Set<WordStack> = []
    @State private var saveError: Error?

    private var currentLevel: Int { userProgress?.level ?? 1 }

    var body: some View {
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: theme.spacing.lg) {
                    infoSection
                    mandatoryStacksSection
                    optionalStacksSection
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
        .onAppear {
            loadSelectedStacks()
        }
        .alert("Save Failed", isPresented: .constant(saveError != nil), presenting: saveError) { _ in
            Button("OK") {
                saveError = nil
            }
        } message: { error in
            Text("Failed to save your changes: \(error.localizedDescription)")
        }
    }

    private var infoSection: some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(theme.colors.accent)
                .accessibilityHidden(true)

            Text("stacks.info")
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
        }
        .padding(theme.spacing.md)
        .background(theme.colors.accentBg)
        .cornerRadius(8)
    }

    private var mandatoryStacksSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("stacks.section.core")
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.inkFaint)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, theme.spacing.sm)

            VStack(spacing: theme.spacing.sm) {
                ForEach(WordStack.mandatoryStacks(for: currentLevel).sorted(by: { $0.displayName < $1.displayName })) { stack in
                    StackCard(stack: stack, isSelected: true, isMandatory: true, onToggle: {})
                }
            }
        }
    }

    private var optionalStacksSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("stacks.section.optional")
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.inkFaint)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, theme.spacing.sm)

            VStack(spacing: theme.spacing.sm) {
                ForEach(WordStack.availableOptionalStacks(for: currentLevel).sorted(by: { $0.displayName < $1.displayName })) { stack in
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
