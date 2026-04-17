import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Query private var userProgressList: [UserProgress]

    var userProgress: UserProgress? {
        userProgressList.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.bg.ignoresSafeArea()

                ScrollView {
                    if let progress = userProgress {
                        VStack(spacing: theme.spacing.lg) {
                            levelSection(progress: progress)

                            streakSection(progress: progress)

                            statsSection(progress: progress)

                            masteredSection(progress: progress)

                            bookmarkedSection(progress: progress)

                            settingsSection(progress: progress)
                        }
                        .padding(theme.spacing.lg)
                    }
                }
            }
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func levelSection(progress: UserProgress) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            if let levelDef = LevelDefinition.definition(for: progress.level) {
                HStack {
                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        Text("Level \(progress.level)")
                            .font(TypographyTokens.title1)
                            .foregroundColor(theme.colors.ink)

                        Text(levelDef.title)
                            .font(TypographyTokens.headline)
                            .foregroundColor(theme.colors.inkMuted)
                    }

                    Spacer()
                }

                if let levelProgress = LevelDefinition.progressToNextLevel(
                    currentLevel: progress.level,
                    wordsAssessedCorrectlyTwice: progress.wordsAssessedCorrectlyTwice
                ) {
                    VStack(alignment: .leading, spacing: theme.spacing.sm) {
                        ProgressView(value: levelProgress.progress)
                            .tint(theme.colors.accent)

                        Text("\(Int(levelProgress.progress * 100))% • \(levelProgress.wordsRemaining) words to \(levelProgress.nextLevel.title)")
                            .font(TypographyTokens.caption)
                            .foregroundColor(theme.colors.inkMuted)
                    }
                }
            }
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private func streakSection(progress: UserProgress) -> some View {
        HStack(spacing: theme.spacing.xl) {
            VStack(spacing: theme.spacing.xs) {
                HStack(spacing: theme.spacing.xs) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(theme.colors.accent)
                    Text("\(progress.currentStreak)")
                        .font(TypographyTokens.title1)
                        .foregroundColor(theme.colors.ink)
                }
                Text("Current Streak")
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkMuted)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 60)

            VStack(spacing: theme.spacing.xs) {
                Text("\(progress.longestStreak)")
                    .font(TypographyTokens.title1)
                    .foregroundColor(theme.colors.ink)
                Text("Longest Streak")
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private func statsSection(progress: UserProgress) -> some View {
        VStack(spacing: theme.spacing.md) {
            StatRow(label: "Words Practiced", value: "\(progress.wordsPracticedCount)")
            Divider().background(theme.colors.line)
            StatRow(label: "Assessed Correctly (2×)", value: "\(progress.wordsAssessedCorrectlyTwice)")
            Divider().background(theme.colors.line)
            StatRow(label: "Words Mastered", value: "\(progress.masteredWordIds.count)")
            Divider().background(theme.colors.line)
            StatRow(label: "Bookmarked", value: "\(progress.bookmarkedWordIds.count)")
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private func masteredSection(progress: UserProgress) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Mastered Words")
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.ink)

            if progress.masteredWordIds.isEmpty {
                Text("No mastered words yet")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
            } else {
                Text("\(progress.masteredWordIds.count) words mastered")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
            }
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private func bookmarkedSection(progress: UserProgress) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Saved Words")
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.ink)

            if progress.bookmarkedWordIds.isEmpty {
                Text("No saved words yet")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
            } else {
                Text("\(progress.bookmarkedWordIds.count) words saved")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
            }
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private func settingsSection(progress: UserProgress) -> some View {
        VStack(spacing: 0) {
            NavigationLink(destination: StackManagementView()) {
                SettingsRowContent(
                    icon: "square.stack.3d.up.fill",
                    title: "Manage Stacks",
                    subtitle: "\(progress.selectedStacks.count) active"
                )
            }
            .buttonStyle(.plain)

            Divider().background(theme.colors.line)

            SettingsRow(
                icon: "bell.fill",
                title: "Notifications",
                action: {}
            )

            Divider().background(theme.colors.line)

            SettingsRow(
                icon: "paintbrush.fill",
                title: "Theme",
                subtitle: progress.themePreference.rawValue.capitalized,
                action: {}
            )

            Divider().background(theme.colors.line)

            SettingsRow(
                icon: "rectangle.compress.vertical",
                title: "Card Density",
                subtitle: progress.densityPreference.rawValue.capitalized,
                action: {}
            )
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }
}

struct StatRow: View {
    @Environment(\.theme) private var theme

    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)

            Spacer()

            Text(value)
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.ink)
        }
    }
}

struct SettingsRow: View {
    @Environment(\.theme) private var theme

    let icon: String
    let title: String
    var subtitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowContent(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsRowContent: View {
    @Environment(\.theme) private var theme

    let icon: String
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.colors.accent)
                .frame(width: 24)

            Text(title)
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.ink)

            Spacer()

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkMuted)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(theme.colors.inkFaint)
        }
        .padding(.vertical, theme.spacing.sm)
    }
}
