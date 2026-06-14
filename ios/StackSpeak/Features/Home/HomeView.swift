import SwiftUI
import SwiftData
import UserNotifications

/// Today (Home) — list-first view of the day's 5 words.
///
/// The user picks a word from the list and drills into a single-word Feynman
/// flow (`WordFeynmanScreen`). Resolves the previous "deck" pattern where
/// inter-word swipe and intra-card swipe both felt like the same gesture —
/// list nav is unambiguous, the daily progress is visible at a glance, and
/// each word feels like an intentional pick.
struct HomeView: View {
    @Environment(\.theme) var theme
    @Environment(\.services) var services
    @Environment(\.userProgress) var userProgress
    @Environment(\.tabRouter) var tabRouter

    // Restrict to the last 10 days — `lastTenDays()` never looks further back, so
    // there is no value in loading every historical row on every body eval.
    @Query var dailySets: [DailySet]
    @State var viewModel = HomeViewModel()

    init() {
        let cal = Calendar.current
        // Compute the oldest day-string we could ever need (9 days ago).
        let nineAgo = cal.date(byAdding: .day, value: -9, to: cal.startOfDay(for: Date())) ?? Date()
        let cutoff = DailySet.dayString(from: nineAgo)
        _dailySets = Query(filter: #Predicate<DailySet> { $0.dayString >= cutoff })
    }
    @State var notificationAuthStatus: UNAuthorizationStatus = .notDetermined
    @State var showNotificationBanner = false
    @State var showNotificationPrompt = false
    @State private var showStackManagement = false
    @State var showWordGoalEditor = false
    @State var showProSheet = false
    @State var path: [UUID] = []

    // Fresh-install / reinstall restore nudge: shown on Home only while there's
    // no local progress and no linked account, so a returning user can find
    // the sign-in path. Dismissal persists; the prompt also self-hides once any
    // word is practiced or an account is linked.
    @AppStorage("home.restorePromptDismissed") var restorePromptDismissed = false
    @AppStorage(SyncDefaults.accountLinkedKey) var accountLinked = false

    var body: some View {
        NavigationStack(path: $path) {
            navigationContent
        }
    }

    private var navigationContent: some View {
        mainZStack
            .navigationTitle("home.navTitle")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        BookmarksView()
                    } label: {
                        Image(systemName: "bookmark.fill")
                            .foregroundColor(theme.colors.accent)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text("a11y.openBookmarks"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    dayCounterBadge
                }
            }
            .navigationDestination(for: UUID.self) { wordId in
                wordDestination(wordId: wordId)
            }
            .task { await initialLoad() }
            .onChange(of: userProgress?.masteredWordIds) { _, _ in
                Task { await reloadIfNeeded() }
            }
            .onChange(of: services?.catalogStatus) { _, newStatus in
                if case .loaded = newStatus, viewModel.todaysWords.isEmpty {
                    Task { await reloadIfNeeded() }
                }
            }
            .alert("notifications.prompt.title", isPresented: $showNotificationPrompt) {
                notificationAlertButtons
            } message: {
                Text("notifications.prompt.message")
            }
            // Anchored here, not on the all-mastered EmptyStateView: saving
            // stacks can repopulate todaysWords, and a sheet on the vanishing
            // branch would be force-dismissed mid-flow.
            .sheet(isPresented: $showStackManagement) {
                NavigationStack {
                    StackManagementView()
                }
            }
            .sheet(isPresented: $showWordGoalEditor) {
                DailyWordGoalSheet(
                    current: userProgress?.dailyWordGoal ?? 5,
                    onApply: applyWordGoal
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showProSheet) {
                ProGateSheet()
            }
    }

    /// Applies a new daily word goal (Pro): reshapes today's set immediately and
    /// reloads. The synced preference propagates on the next sync cycle.
    private func applyWordGoal(_ goal: Int) {
        guard let progress = userProgress, let services else { return }
        do {
            try services.word.setDailyWordGoal(goal, userProgress: progress)
        } catch {
            viewModel.errorMessage = error.localizedDescription
            return
        }
        Task { await viewModel.loadTodaysWords(wordService: services.word, userProgress: progress) }
    }

    private var mainZStack: some View {
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            if let progress = userProgress {
                content(progress: progress)
            }

            if let error = viewModel.errorMessage {
                VStack(spacing: theme.spacing.sm) {
                    Spacer()
                    Text(error)
                        .font(TypographyTokens.callout)
                        .foregroundColor(theme.colors.warn)
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await initialLoad() }
                    } label: {
                        Text("home.error.retry")
                            .font(TypographyTokens.headline)
                            .foregroundColor(theme.colors.accent)
                            .frame(minWidth: 88, minHeight: 44)
                            .padding(.horizontal, theme.spacing.md)
                            .background(theme.colors.accentBg)
                            .clipShape(.rect(cornerRadius: RadiusTokens.card))
                    }
                    .accessibilityHint(Text(error))
                }
                .padding()
            }
        }
    }

    private func initialLoad() async {
        if let progress = userProgress, let services {
            await viewModel.loadTodaysWords(wordService: services.word, userProgress: progress)
        }
        await checkNotificationStatus()
    }

    private func reloadIfNeeded() async {
        if let progress = userProgress, let services {
            await viewModel.loadTodaysWords(wordService: services.word, userProgress: progress)
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func content(progress: UserProgress) -> some View {
        VStack(spacing: theme.spacing.md) {
            if shouldShowRestorePrompt(progress) {
                restorePrompt
                    .padding(.horizontal, theme.spacing.lg)
            }

            if showNotificationBanner && notificationAuthStatus == .denied && !progress.wordsPracticedIds.isEmpty {
                notificationBanner
                    .padding(.horizontal, theme.spacing.lg)
            }

            statusLine(progress: progress)
                .padding(.horizontal, theme.spacing.lg)

            if !viewModel.hasLoaded {
                // Still computing today's set — show a spinner rather than
                // briefly flashing the all-mastered state on the empty list.
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, theme.spacing.xxl)
            } else if viewModel.todaysWords.isEmpty && viewModel.errorMessage == nil {
                // The most engaged users land here — give them somewhere to go.
                EmptyStateView(
                    icon: "checkmark.seal.fill",
                    title: "home.allMastered.title",
                    message: "home.allMastered.message",
                    actionTitle: "home.allMastered.browseLibrary",
                    action: { tabRouter?.selection = .books },
                    secondaryActionTitle: "home.allMastered.manageStacks",
                    secondaryAction: { showStackManagement = true }
                )
            } else {
                sectionDivider
                    .padding(.horizontal, theme.spacing.lg)

                CompletionTrackerRow(days: lastTenDays())
                    .padding(.horizontal, theme.spacing.lg)

                sectionDivider
                    .padding(.horizontal, theme.spacing.lg)

                instructionLine
                    .padding(.horizontal, theme.spacing.lg)

                wordList(progress: progress)
            }
        }
        .frame(maxWidth: LayoutTokens.contentMaxWidth)
        .padding(.vertical, theme.spacing.md)
    }

    /// Single quiet status line: level + streak.
    private func statusLine(progress: UserProgress) -> some View {
        HStack(spacing: theme.spacing.xs) {
            if let levelDef = LevelDefinition.definition(for: progress.level) {
                Text(levelDef.title)
                    .font(TypographyTokens.subheadline)
                    .foregroundColor(theme.colors.inkMuted)
            }
            Text("·")
                .font(TypographyTokens.subheadline)
                .foregroundColor(theme.colors.inkFaint)
            HStack(spacing: theme.spacing.xs) {
                Image(systemName: "flame.fill")
                    .font(.system(.caption))
                    .foregroundColor(theme.colors.streak)
                Text(progress.displayedCurrentStreak == 0
                     ? String(localized: "home.streak.start")
                     : String(format: String(localized: "home.streak.day.format"),
                              progress.displayedCurrentStreak))
                    .font(TypographyTokens.subheadline)
                    .foregroundColor(theme.colors.ink)
                    .contentTransition(.numericText())
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: String(localized: "a11y.streak.format"), progress.displayedCurrentStreak))
    }

}

#Preview("Home - Light") {
    HomeView()
        .withTheme(ThemeManager())
}

#Preview("Home - Dark") {
    HomeView()
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
