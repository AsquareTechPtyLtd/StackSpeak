import SwiftUI
import SwiftData
import UIKit
import UserNotifications

/// Today (Home) — daily Feynman deck.
///
/// T1 — header card collapsed to a single status line ("Intern Band 2 · day 7 🔥").
///   The previous bordered card with three competing focal points is gone.
/// T2 — progress dots replaced by an `n/5 today` mono caption above the deck.
/// CC2 — the level/streak status appears here once. Profile owns the
///   detailed progress bar; per-card meta in the Feynman card was removed.
struct HomeView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.userProgress) private var userProgress

    @State private var viewModel = HomeViewModel()
    @State private var notificationAuthStatus: UNAuthorizationStatus = .notDetermined
    @State private var showNotificationBanner = false
    @State private var showNotificationPrompt = false
    @State private var showLevelUp = false
    @State private var levelUpTarget: Int?

    var body: some View {
        NavigationStack {
            navigationContent
        }
    }

    private var navigationContent: some View {
        mainZStack
            .navigationTitle("home.navTitle")
            .navigationBarTitleDisplayMode(.large)
            .task { await initialLoad() }
            .onChange(of: userProgress?.masteredWordIds) { _, _ in
                Task { await reloadIfNeeded() }
            }
            .onChange(of: services?.catalogStatus) { _, newStatus in
                if case .loaded = newStatus, viewModel.todaysWords.isEmpty {
                    Task { await reloadIfNeeded() }
                }
            }
            .onChange(of: viewModel.justCompletedDay) { _, completed in
                if completed, let progress = userProgress {
                    handleDayJustCompleted(progress: progress)
                }
            }
            .alert("notifications.prompt.title", isPresented: $showNotificationPrompt) {
                notificationAlertButtons
            } message: {
                Text("notifications.prompt.message")
            }
            .sheet(isPresented: $showLevelUp) {
                if let level = levelUpTarget, let progress = userProgress {
                    LevelUpView(newLevel: level, userProgress: progress)
                }
            }
    }

    private var mainZStack: some View {
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            if let progress = userProgress {
                content(progress: progress)
            }

            if let error = viewModel.errorMessage {
                VStack {
                    Spacer()
                    Text(error)
                        .font(TypographyTokens.callout)
                        .foregroundColor(theme.colors.warn)
                        .padding()
                }
            }
        }
    }

    @ViewBuilder
    private var notificationAlertButtons: some View {
        Button("notifications.prompt.enable") {
            Task { _ = try? await services?.notification.requestAuthorization() }
        }
        Button("notifications.prompt.notNow", role: .cancel) { }
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
            if showNotificationBanner && notificationAuthStatus == .denied && !progress.wordsPracticedIds.isEmpty {
                notificationBanner
                    .padding(.horizontal, theme.spacing.lg)
            }

            statusLine(progress: progress)
                .padding(.horizontal, theme.spacing.lg)

            if viewModel.todaysWords.isEmpty && viewModel.errorMessage == nil {
                EmptyStateView(
                    icon: "checkmark.seal.fill",
                    title: "home.allMastered.title",
                    message: "home.allMastered.message"
                )
            } else {
                dayCounter(progress: progress)
                    .padding(.horizontal, theme.spacing.lg)

                deck(progress: progress)
            }
        }
        .frame(maxWidth: 720)
        .padding(.vertical, theme.spacing.md)
    }

    /// T1 — single quiet status line replaces the three-element header card.
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
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12))
                    .foregroundColor(theme.colors.streak)
                    .symbolEffect(.bounce, value: progress.displayedCurrentStreak)
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

    /// T2 — `n / 5 today` mono caption replaces the 5-capsule progress dots.
    private func dayCounter(progress: UserProgress) -> some View {
        let total = viewModel.dailySet?.wordIds.count ?? 0
        let done = (viewModel.dailySet?.wordIds ?? [])
            .filter { viewModel.isWordCompleted($0) }
            .count
        return HStack {
            Text(String(format: String(localized: "home.dayCounter.format"), done, total))
                .font(TypographyTokens.mono)
                .foregroundColor(theme.colors.inkMuted)
                .contentTransition(.numericText())
            Spacer()
        }
    }

    private func deck(progress: UserProgress) -> some View {
        TabView(selection: $viewModel.currentIndex) {
            ForEach(Array(viewModel.todaysWords.enumerated()), id: \.element.id) { index, word in
                FeynmanCardView(
                    word: word,
                    userProgress: progress,
                    isCompleted: viewModel.isWordCompleted(word.id),
                    latestExplanation: viewModel.latestExplanation(for: word.id, userProgress: progress),
                    onSubmit: { explanation, method, markAsMastered in
                        submit(wordId: word.id, explanation: explanation, method: method, markAsMastered: markAsMastered, progress: progress)
                    }
                )
                .id(word.id)
                .padding(.horizontal, theme.spacing.lg)
                .padding(.bottom, theme.spacing.md)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notificationBanner: some View {
        HStack(spacing: theme.spacing.md) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                HStack(spacing: theme.spacing.xs) {
                    Image(systemName: "bell.fill")
                        .foregroundColor(theme.colors.accent)
                    Text("notifications.banner.title")
                        .font(TypographyTokens.headline)
                        .foregroundColor(theme.colors.ink)
                }
                Text("notifications.banner.message")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
            }
            Spacer()
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("notifications.banner.enable")
                    .font(TypographyTokens.callout.weight(.semibold))
                    .foregroundColor(theme.colors.accent)
            }
            Button(action: { showNotificationBanner = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(theme.colors.inkFaint)
            }
        }
        .padding(theme.spacing.cardPadding)
        .background(theme.colors.accentBg)
        .clipShape(.rect(cornerRadius: RadiusTokens.card))
    }

    // MARK: - Actions

    private func submit(wordId: UUID, explanation: String, method: InputMethod, markAsMastered: Bool, progress: UserProgress) {
        guard let services else { return }
        let firstEverPractice = progress.wordsPracticedIds.isEmpty
        viewModel.submitExplanation(
            for: wordId,
            explanation: explanation,
            inputMethod: method,
            markAsMastered: markAsMastered,
            services: services,
            userProgress: progress
        )
        if firstEverPractice && !progress.notificationEnabled {
            showNotificationPrompt = true
        }
    }

    private func handleDayJustCompleted(progress: UserProgress) {
        viewModel.justCompletedDay = false
        // Level-up is triggered by assessments, not Feynman submissions.
        // Reset the flag — LevelUpView is kept wired for future use.
        _ = progress
    }

    private func checkNotificationStatus() async {
        guard let services else { return }
        notificationAuthStatus = await services.notification.checkAuthorizationStatus()
        if notificationAuthStatus == .denied, let progress = userProgress, !progress.wordsPracticedIds.isEmpty {
            showNotificationBanner = true
        }
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
