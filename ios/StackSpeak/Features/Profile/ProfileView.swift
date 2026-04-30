import SwiftUI

/// P1 — converted to a native Form with grouped sections. Replaces six
/// stacked cards with iOS-native list grouping; gets free Dynamic Type,
/// VoiceOver, and the ambient affordance pattern users already know from
/// Settings.app.
struct ProfileView: View {
    @Environment(\.theme) private var theme
    @Environment(\.userProgress) private var userProgress

    var body: some View {
        NavigationStack {
            Form {
                if let progress = userProgress {
                    levelSection(progress: progress)
                    streakSection(progress: progress)
                    statsSection(progress: progress)
                    collectionSection(progress: progress)
                    settingsSection(progress: progress)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.bg)
            .navigationTitle("profile.navTitle")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func levelSection(progress: UserProgress) -> some View {
        if let levelDef = LevelDefinition.definition(for: progress.level) {
            Section {
                VStack(alignment: .leading, spacing: theme.spacing.sm) {
                    Text(levelDef.title)
                        .font(TypographyTokens.title2)
                        .foregroundColor(theme.colors.ink)
                    if let levelProgress = LevelDefinition.progressToNextLevel(
                        currentLevel: progress.level,
                        wordsAssessedCorrectlyTwice: progress.wordsAssessedCorrectlyTwice
                    ) {
                        ProgressView(value: levelProgress.progress)
                            .tint(theme.colors.accent)
                            .accessibilityLabel("Level progress: \(Int(levelProgress.progress * 100))%")
                        Text("\(Int(levelProgress.progress * 100))% • \(levelProgress.wordsRemaining) to \(levelProgress.nextLevel.title)")
                            .font(TypographyTokens.footnote)
                            .foregroundColor(theme.colors.inkMuted)
                    }
                }
                .padding(.vertical, theme.spacing.xs)
            }
        }
    }

    private func streakSection(progress: UserProgress) -> some View {
        Section {
            HStack(spacing: theme.spacing.xl) {
                streakCell(
                    value: progress.displayedCurrentStreak,
                    label: "profile.streak.current",
                    showFlame: true
                )
                Divider().frame(height: 44)
                streakCell(
                    value: progress.longestStreak,
                    label: "profile.streak.longest",
                    showFlame: false
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacing.xs)
        }
    }

    private func streakCell(value: Int, label: LocalizedStringKey, showFlame: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if showFlame {
                    Image(systemName: "flame.fill")
                        .foregroundColor(theme.colors.streak)
                        .symbolEffect(.bounce, value: value)
                        .accessibilityHidden(true)
                }
                Text("\(value)")
                    .font(TypographyTokens.title1)
                    .foregroundColor(theme.colors.ink)
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func statsSection(progress: UserProgress) -> some View {
        Section {
            statRow(label: "profile.stats.practiced", value: progress.wordsPracticedCount)
            statRow(label: "profile.stats.assessedTwice", value: progress.wordsAssessedCorrectlyTwice)
            statRow(label: "profile.stats.mastered", value: progress.masteredWordIds.count)
            statRow(label: "profile.stats.bookmarked", value: progress.bookmarkedWordIds.count)
        }
    }

    private func statRow(label: LocalizedStringKey, value: Int) -> some View {
        HStack {
            Text(label)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
            Spacer()
            Text("\(value)")
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.inkMuted)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    /// P2 — Mastered & Bookmarked are real navigation targets.
    /// Saved combines word + card bookmarks under one entry per the Pro/Books plan.
    private func collectionSection(progress: UserProgress) -> some View {
        Section {
            NavigationLink {
                WordListView(
                    title: "profile.mastered.title",
                    wordIds: progress.masteredWordIds,
                    emptyTitle: "profile.mastered.empty",
                    emptyMessage: "profile.mastered.hint"
                )
            } label: {
                collectionRow(icon: "checkmark.seal.fill",
                              tint: theme.colors.good,
                              title: "profile.mastered.title",
                              count: progress.masteredWordIds.count)
            }
            NavigationLink {
                BookmarksView()
            } label: {
                collectionRow(icon: "bookmark.fill",
                              tint: theme.colors.accent,
                              title: "bookmarks.navTitle",
                              count: progress.bookmarkedWordIds.count)
            }
        }
    }

    private func collectionRow(icon: String, tint: Color, title: LocalizedStringKey, count: Int) -> some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: icon)
                .font(.system(.subheadline))
                .foregroundColor(tint)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(title)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
            Spacer()
            Text("\(count)")
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.inkMuted)
        }
    }

    private func settingsSection(progress: UserProgress) -> some View {
        Section {
            NavigationLink {
                StackManagementView()
            } label: {
                settingsRow(
                    icon: "square.stack.3d.up.fill",
                    title: "profile.settings.manageStacks",
                    subtitle: "\(progress.selectedStacks.count) active"
                )
            }
            NavigationLink {
                NotificationSettingsView()
            } label: {
                settingsRow(
                    icon: "bell.fill",
                    title: "profile.settings.notifications",
                    subtitle: progress.notificationEnabled ? "On" : "Off"
                )
            }
            NavigationLink {
                ThemeSettingsView()
            } label: {
                settingsRow(
                    icon: "paintbrush.fill",
                    title: "profile.settings.theme",
                    subtitle: progress.themePreference.rawValue.capitalized
                )
            }
        }
    }

    private func settingsRow(icon: String, title: LocalizedStringKey, subtitle: String) -> some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: icon)
                .font(.system(.subheadline))
                .foregroundColor(theme.colors.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(title)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
            Spacer()
            Text(subtitle)
                .font(TypographyTokens.footnote)
                .foregroundColor(theme.colors.inkMuted)
        }
    }
}

#Preview("Profile - Light") {
    ProfileView().withTheme(ThemeManager())
}

#Preview("Profile - Dark") {
    ProfileView()
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
