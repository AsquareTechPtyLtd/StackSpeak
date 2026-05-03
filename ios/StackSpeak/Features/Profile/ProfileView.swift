import SwiftUI
import SwiftData

/// Profile rendered as a stack of cards on the shared `surface` chrome,
/// matching the visual language used by Home, WordDetail, and the Feynman
/// card. Replaces the prior native `Form` (which fragmented the design
/// language with iOS Settings grouping).
struct ProfileView: View {
    @Environment(\.theme) var theme
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) var modelContext

    @State private var showProSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.xl) {
                    if let progress = userProgress {
                        sectionGroup("profile.section.level") { levelSection(progress: progress) }
                        sectionGroup("profile.section.streak") { streakSection(progress: progress) }
                        sectionGroup("profile.section.stats") { statsSection(progress: progress) }
                        sectionGroup("profile.section.collections") { collectionSection(progress: progress) }
                        sectionGroup("profile.section.settings") { settingsSection(progress: progress) }
                        sectionGroup("profile.section.developer") { devSection(progress: progress) }
                    }
                }
                .padding(.horizontal, theme.spacing.lg)
                .padding(.vertical, theme.spacing.lg)
            }
            .background(theme.colors.bg)
            .navigationTitle("profile.navTitle")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let p = userProgress, !p.isProActive {
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
            }
            .sheet(isPresented: $showProSheet) {
                ProGateSheet().presentationDetents([.medium])
            }
        }
    }

    private func sectionGroup<Content: View>(
        _ titleKey: LocalizedStringKey,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            SectionHeader(titleKey)
            content()
        }
    }

    func cardSurface<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(theme.spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardChrome()
    }

    // MARK: - Sections

    @ViewBuilder
    private func levelSection(progress: UserProgress) -> some View {
        if let levelDef = LevelDefinition.definition(for: progress.level) {
            cardSurface {
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
            }
        }
    }

    private func streakSection(progress: UserProgress) -> some View {
        cardSurface {
            HStack(spacing: theme.spacing.xl) {
                streakCell(value: progress.displayedCurrentStreak, label: "profile.streak.current", showFlame: true)
                Divider().frame(height: 44)
                streakCell(value: progress.longestStreak, label: "profile.streak.longest", showFlame: false)
            }
            .frame(maxWidth: .infinity)
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
        cardSurface {
            VStack(spacing: theme.spacing.md) {
                statRow(label: "profile.stats.practiced", value: progress.wordsPracticedCount)
                statRow(label: "profile.stats.assessedTwice", value: progress.wordsAssessedCorrectlyTwice)
                statRow(label: "profile.stats.mastered", value: progress.masteredWordIds.count)
                statRow(label: "profile.stats.bookmarked", value: progress.bookmarkedWordIds.count)
            }
        }
    }

    private func statRow(label: LocalizedStringKey, value: Int) -> some View {
        HStack {
            Text(label).font(TypographyTokens.body).foregroundColor(theme.colors.ink)
            Spacer()
            Text("\(value)").font(TypographyTokens.body).foregroundColor(theme.colors.inkMuted)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    private func collectionSection(progress: UserProgress) -> some View {
        cardSurface {
            VStack(spacing: 0) {
                NavigationLink {
                    WordListView(title: "profile.mastered.title", wordIds: progress.masteredWordIds,
                                 emptyTitle: "profile.mastered.empty", emptyMessage: "profile.mastered.hint")
                } label: {
                    collectionRow(icon: "checkmark.seal.fill", tint: theme.colors.good,
                                  title: "profile.mastered.title", count: progress.masteredWordIds.count)
                }
                .buttonStyle(.plain)
                Divider()
                NavigationLink { BookmarksView() } label: {
                    collectionRow(icon: "bookmark.fill", tint: theme.colors.accent,
                                  title: "bookmarks.navTitle", count: progress.bookmarkedWordIds.count)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func collectionRow(icon: String, tint: Color, title: LocalizedStringKey, count: Int) -> some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: icon).font(.system(.subheadline)).foregroundColor(tint)
                .frame(width: 24).accessibilityHidden(true)
            Text(title).font(TypographyTokens.body).foregroundColor(theme.colors.ink)
            Spacer()
            Text("\(count)").font(TypographyTokens.body).foregroundColor(theme.colors.inkMuted)
            Image(systemName: "chevron.right").font(.system(.subheadline))
                .foregroundColor(theme.colors.inkFaint).accessibilityHidden(true)
        }
        .padding(.vertical, theme.spacing.xs)
        .contentShape(Rectangle())
    }

    private func settingsSection(progress: UserProgress) -> some View {
        cardSurface {
            VStack(spacing: 0) {
                NavigationLink { StackManagementView() } label: {
                    settingsRow(icon: "square.stack.3d.up.fill", title: "profile.settings.manageStacks",
                                subtitle: "\(progress.selectedStacks.count) active")
                }
                .buttonStyle(.plain)
                Divider()
                NavigationLink { NotificationSettingsView() } label: {
                    settingsRow(icon: "bell.fill", title: "profile.settings.notifications",
                                subtitle: progress.notificationEnabled ? "On" : "Off")
                }
                .buttonStyle(.plain)
                Divider()
                NavigationLink { ThemeSettingsView() } label: {
                    settingsRow(icon: "paintbrush.fill", title: "profile.settings.theme",
                                subtitle: progress.themePreference.rawValue.capitalized)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func settingsRow(icon: String, title: LocalizedStringKey, subtitle: String) -> some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: icon).font(.system(.subheadline)).foregroundColor(theme.colors.accent)
                .frame(width: 24).accessibilityHidden(true)
            Text(title).font(TypographyTokens.body).foregroundColor(theme.colors.ink)
            Spacer()
            Text(subtitle).font(TypographyTokens.footnote).foregroundColor(theme.colors.inkMuted)
            Image(systemName: "chevron.right").font(.system(.subheadline))
                .foregroundColor(theme.colors.inkFaint).accessibilityHidden(true)
        }
        .padding(.vertical, theme.spacing.xs)
        .contentShape(Rectangle())
    }
}

#Preview("Profile - Light") {
    ProfileView().withTheme(ThemeManager())
}

#Preview("Profile - Dark") {
    ProfileView().withTheme(ThemeManager()).preferredColorScheme(.dark)
}
