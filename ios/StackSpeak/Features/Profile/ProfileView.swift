import SwiftUI

struct ProfileView: View {
    @Environment(\.theme) private var theme
    @Environment(\.userProgress) private var userProgress

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
                        .frame(maxWidth: 720)
                        .padding(theme.spacing.lg)
                    }
                }
            }
            .navigationTitle("profile.navTitle")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func levelSection(progress: UserProgress) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            if let levelDef = LevelDefinition.definition(for: progress.level) {
                HStack {
                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        Text(levelDef.title)
                            .font(TypographyTokens.title1)
                            .foregroundColor(theme.colors.ink)

                        Text(levelDef.description)
                            .font(TypographyTokens.callout)
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
                            .accessibilityLabel("Level progress: \(Int(levelProgress.progress * 100))%")

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
                        .accessibilityHidden(true)
                    Text("\(progress.displayedCurrentStreak)")
                        .font(TypographyTokens.title1)
                        .foregroundColor(theme.colors.ink)
                }
                Text("profile.streak.current")
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Current streak: \(progress.displayedCurrentStreak) days")

            Divider().frame(height: 60)

            VStack(spacing: theme.spacing.xs) {
                Text("\(progress.longestStreak)")
                    .font(TypographyTokens.title1)
                    .foregroundColor(theme.colors.ink)
                Text("profile.streak.longest")
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Longest streak: \(progress.longestStreak) days")
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private func statsSection(progress: UserProgress) -> some View {
        VStack(spacing: theme.spacing.md) {
            StatRow(label: String(localized: "profile.stats.practiced"), value: "\(progress.wordsPracticedCount)")
            Divider().background(theme.colors.line)
            StatRow(label: String(localized: "profile.stats.assessedTwice"), value: "\(progress.wordsAssessedCorrectlyTwice)")
            Divider().background(theme.colors.line)
            StatRow(label: String(localized: "profile.stats.mastered"), value: "\(progress.masteredWordIds.count)")
            Divider().background(theme.colors.line)
            StatRow(label: String(localized: "profile.stats.bookmarked"), value: "\(progress.bookmarkedWordIds.count)")
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private func masteredSection(progress: UserProgress) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("profile.mastered.title")
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.ink)

            if progress.masteredWordIds.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text("profile.mastered.empty")
                        .font(TypographyTokens.callout)
                        .foregroundColor(theme.colors.inkMuted)
                    Text("profile.mastered.hint")
                        .font(TypographyTokens.caption)
                        .foregroundColor(theme.colors.inkFaint)
                }
            } else {
                Text(String(format: String(localized: "profile.mastered.count.format"),
                            progress.masteredWordIds.count))
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
            Text("profile.saved.title")
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.ink)

            if progress.bookmarkedWordIds.isEmpty {
                Text("profile.saved.empty")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
            } else {
                Text(String(format: String(localized: "profile.saved.count.format"),
                            progress.bookmarkedWordIds.count))
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
                    title: String(localized: "profile.settings.manageStacks"),
                    subtitle: "\(progress.selectedStacks.count) active"
                )
            }
            .buttonStyle(.plain)

            Divider().background(theme.colors.line)

            NavigationLink(destination: NotificationSettingsView()) {
                SettingsRowContent(
                    icon: "bell.fill",
                    title: String(localized: "profile.settings.notifications"),
                    subtitle: progress.notificationEnabled ? "On" : "Off"
                )
            }
            .buttonStyle(.plain)

            Divider().background(theme.colors.line)

            NavigationLink(destination: ThemeSettingsView()) {
                SettingsRowContent(
                    icon: "paintbrush.fill",
                    title: String(localized: "profile.settings.theme"),
                    subtitle: progress.themePreference.rawValue.capitalized
                )
            }
            .buttonStyle(.plain)

            Divider().background(theme.colors.line)

            NavigationLink(destination: DensitySettingsView()) {
                SettingsRowContent(
                    icon: "rectangle.compress.vertical",
                    title: String(localized: "profile.settings.density"),
                    subtitle: progress.densityPreference.rawValue.capitalized
                )
            }
            .buttonStyle(.plain)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
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
                .accessibilityHidden(true)

            Text(title)
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.ink)

            Spacer()

            if let subtitle {
                Text(subtitle)
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkMuted)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(theme.colors.inkFaint)
                .accessibilityHidden(true)
        }
        .padding(.vertical, theme.spacing.sm)
    }
}
