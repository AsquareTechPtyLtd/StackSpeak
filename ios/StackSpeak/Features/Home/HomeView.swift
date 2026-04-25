import SwiftUI
import SwiftData
import UIKit
import UserNotifications

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

            headerSection(progress: progress)
                .padding(.horizontal, theme.spacing.lg)

            if viewModel.todaysWords.isEmpty && viewModel.errorMessage == nil {
                allMasteredState
            } else {
                progressDots(progress: progress)
                    .padding(.horizontal, theme.spacing.lg)

                deck(progress: progress)
            }
        }
        .frame(maxWidth: 720)
        .padding(.vertical, theme.spacing.md)
    }

    private func headerSection(progress: UserProgress) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                if let levelDef = LevelDefinition.definition(for: progress.level) {
                    Text(levelDef.title)
                        .font(TypographyTokens.headline)
                        .foregroundColor(theme.colors.ink)
                }

                if let levelProgress = LevelDefinition.progressToNextLevel(
                    currentLevel: progress.level,
                    wordsAssessedCorrectlyTwice: progress.wordsAssessedCorrectlyTwice
                ) {
                    ProgressView(value: levelProgress.progress)
                        .tint(theme.colors.accent)
                        .accessibilityLabel(String(format: String(localized: "a11y.levelProgress.format"), Int(levelProgress.progress * 100)))

                    Text(String(format: String(localized: "home.levelProgress.format"),
                                Int(levelProgress.progress * 100), levelProgress.wordsRemaining))
                        .font(TypographyTokens.caption)
                        .foregroundColor(theme.colors.inkMuted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: theme.spacing.xs) {
                HStack(spacing: theme.spacing.xs) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.colors.accent)
                    Text("\(progress.displayedCurrentStreak)")
                        .font(TypographyTokens.headline)
                        .foregroundColor(theme.colors.ink)
                }
                Text(progress.displayedCurrentStreak == 0
                     ? String(localized: "home.streak.start")
                     : String(localized: "home.streak.label"))
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkMuted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(format: String(localized: "a11y.streak.format"), progress.displayedCurrentStreak))
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    // MARK: - Progress dots

    private func progressDots(progress: UserProgress) -> some View {
        let wordIds = viewModel.dailySet?.wordIds ?? []
        return HStack(spacing: theme.spacing.sm) {
            ForEach(Array(wordIds.enumerated()), id: \.offset) { index, id in
                let completed = viewModel.isWordCompleted(id)
                let current = index == viewModel.currentIndex
                Button(action: { viewModel.currentIndex = index }) {
                    Capsule()
                        .fill(completed ? theme.colors.accent : (current ? theme.colors.ink.opacity(0.5) : theme.colors.line))
                        .frame(height: 6)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(format: String(localized: "a11y.feynman.cardDot.format"),
                                           index + 1, wordIds.count,
                                           completed ? String(localized: "a11y.completed") : ""))
            }
        }
    }

    // MARK: - Deck

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
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var allMasteredState: some View {
        VStack(spacing: theme.spacing.lg) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(theme.colors.accent)
            Text("home.allMastered.title")
                .font(TypographyTokens.title2)
                .foregroundColor(theme.colors.ink)
            Text("home.allMastered.message")
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.inkMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(theme.spacing.xxxl)
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
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.accentBg)
        .cornerRadius(12)
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
        // Level-up is triggered by assessments, not Feynman submissions. Nothing to do
        // here beyond resetting the flag — LevelUpView is kept wired for future use.
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
