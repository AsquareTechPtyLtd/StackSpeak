import SwiftUI
import SwiftData
import OSLog

/// Level-up moment, split into two beats (LU1):
///   1. Pure celebration: bouncing star, level title, description, single
///      "Continue" CTA. No admin in this view.
///   2. If new optional stacks unlocked, a separate sheet appears for the
///      stack picker. The celebration is never contaminated.
///
/// LU2 — `.symbolEffect(.bounce)` on the star + `.success` haptic on appear.
struct LevelUpView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let logger = Logger(category: "LevelUp")

    let newLevel: Int
    let userProgress: UserProgress

    @State private var hasAppeared = false
    @State private var showStackPicker = false

    var levelDefinition: LevelDefinition? {
        LevelDefinition.definition(for: newLevel)
    }

    var hasNewOptionalStacks: Bool {
        !WordStack.newOptionalStacks(for: newLevel).isEmpty
    }

    /// The content tier newly opened at this level, if this is a tier-gate level.
    /// `nil` for rank-only promotions (a new title but no new content).
    var unlockedTier: ContentTier? {
        ContentTier.unlockedAt(level: newLevel)
    }

    var body: some View {
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            VStack(spacing: theme.spacing.xl) {
                Spacer()
                celebrationContent
                Spacer()
                continueButton
            }
            .padding(theme.spacing.xl)
        }
        .sensoryFeedback(.success, trigger: hasAppeared)
        .onAppear { hasAppeared = true }
        .sheet(isPresented: $showStackPicker, onDismiss: { dismiss() }) {
            LevelUpStackPickerSheet(newLevel: newLevel, userProgress: userProgress)
        }
    }

    private var celebrationContent: some View {
        VStack(spacing: theme.spacing.lg) {
            Image(systemName: "star.circle.fill")
                .scaledIcon(size: IconSizeTokens.hero)
                .foregroundColor(theme.colors.accent)
                .symbolEffect(.bounce.up.byLayer, value: hasAppeared)
                .accessibilityHidden(true)

            if let levelDef = levelDefinition {
                Text("levelUp.youAreNow")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
                    .multilineTextAlignment(.center)

                Text(levelDef.title)
                    .font(TypographyTokens.largeTitle)
                    .foregroundColor(theme.colors.ink)
                    .multilineTextAlignment(.center)

                Text(levelDef.description)
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacing.lg)
            }

            // Tier-gate levels open a new band of content — call it out prominently.
            if let tier = unlockedTier {
                Text(String(format: String(localized: "levelUp.tierUnlocked.format"), tier.displayName))
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.accent)
                    .multilineTextAlignment(.center)
                    .padding(.top, theme.spacing.sm)
            }

            // Mandatory stacks at the new level are auto-added by the progression
            // pipeline; show a single quiet line instead of a configurable list.
            let mandatoryCount = WordStack.newMandatoryStacks(for: newLevel).count
            if mandatoryCount > 0 {
                Text(String(format: String(localized: "levelUp.newCoreStacks.summary"), mandatoryCount))
                    .font(TypographyTokens.footnote)
                    .foregroundColor(theme.colors.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, theme.spacing.sm)
            }
        }
    }

    private var continueButton: some View {
        PrimaryCTAButton(hasNewOptionalStacks
                         ? "levelUp.choosePath"
                         : "levelUp.continue") {
            if hasNewOptionalStacks {
                showStackPicker = true
            } else {
                dismiss()
            }
        }
    }
}

/// LU1 — separate beat. Quiet picker for newly-unlocked optional stacks.
struct LevelUpStackPickerSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let logger = Logger(category: "LevelUp")

    let newLevel: Int
    let userProgress: UserProgress

    @State private var selectedOptionalStacks: Set<WordStack> = []
    @State private var saveError: Error?

    var newOptionalStacks: [WordStack] {
        WordStack.newOptionalStacks(for: newLevel)
            .sorted(by: { $0.displayName < $1.displayName })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing.lg) {
                        VStack(alignment: .leading, spacing: theme.spacing.xs) {
                            Text("levelUp.newOptionalStacks.title")
                                .font(TypographyTokens.title2)
                                .foregroundColor(theme.colors.ink)
                            Text("levelUp.newOptionalStacks.subtitle")
                                .font(TypographyTokens.body)
                                .foregroundColor(theme.colors.inkMuted)
                        }

                        VStack(spacing: theme.spacing.sm) {
                            ForEach(newOptionalStacks) { stack in
                                StackCard(
                                    stack: stack,
                                    isSelected: selectedOptionalStacks.contains(stack),
                                    onToggle: { toggle(stack) }
                                )
                            }
                        }

                        PrimaryCTAButton("levelUp.continue") { saveAndDismiss() }
                            .padding(.top, theme.spacing.md)
                    }
                    .padding(theme.spacing.lg)
                }
            }
            .navigationTitle("levelUp.optional.navTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("levelUp.skip") { dismiss() }
                        .foregroundColor(theme.colors.inkMuted)
                }
            }
            .alert("saveError.title", isPresented: .constant(saveError != nil), presenting: saveError) { _ in
                Button("common.ok") { saveError = nil }
            } message: { error in
                Text(String(format: String(localized: "saveError.levelUpStacks.format"),
                            error.localizedDescription))
            }
        }
    }

    private func toggle(_ stack: WordStack) {
        if selectedOptionalStacks.contains(stack) {
            selectedOptionalStacks.remove(stack)
        } else {
            selectedOptionalStacks.insert(stack)
        }
    }

    private func saveAndDismiss() {
        userProgress.selectedStacks.formUnion(selectedOptionalStacks.map { $0.rawValue })
        do {
            try modelContext.save()
            dismiss()
        } catch {
            logger.error("Failed to save level-up stack selection: \(error.localizedDescription, privacy: .public)")
            saveError = error
        }
    }
}

// L16 is a tier gate (advanced) — exercises the "New tier unlocked" callout.
#Preview("Level Up — tier unlock (Light)") {
    LevelUpView(newLevel: 16, userProgress: UserProgress())
        .withTheme(ThemeManager())
}

#Preview("Level Up — tier unlock (Dark)") {
    LevelUpView(newLevel: 16, userProgress: UserProgress())
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}

// L17 is a rank-only level — no tier callout, just the new title.
#Preview("Level Up — rank only (Light)") {
    LevelUpView(newLevel: 17, userProgress: UserProgress())
        .withTheme(ThemeManager())
}
