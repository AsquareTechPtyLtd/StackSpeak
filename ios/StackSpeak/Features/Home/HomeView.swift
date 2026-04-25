import SwiftUI
import SwiftData
import UIKit
import UserNotifications

/// Today (Home) — list-first view of the day's 5 words.
///
/// The user picks a word from the list and drills into a single-word Feynman
/// flow (`WordFeynmanScreen`). Resolves the previous "deck" pattern where
/// inter-word swipe and intra-card swipe both felt like the same gesture —
/// list nav is unambiguous, the daily progress is visible at a glance, and
/// each word feels like an intentional pick.
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
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            navigationContent
        }
    }

    private var navigationContent: some View {
        mainZStack
            .navigationTitle("home.navTitle")
            .navigationBarTitleDisplayMode(.large)
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
                dayCounter()
                    .padding(.horizontal, theme.spacing.lg)

                wordList(progress: progress)
            }
        }
        .frame(maxWidth: 720)
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

    private func dayCounter() -> some View {
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

    /// The day's 5 words as a vertical list of tappable rows.
    private func wordList(progress: UserProgress) -> some View {
        ScrollView {
            VStack(spacing: theme.spacing.sm) {
                ForEach(Array(viewModel.todaysWords.enumerated()), id: \.element.id) { index, word in
                    Button {
                        path.append(word.id)
                    } label: {
                        TodayWordRow(
                            number: index + 1,
                            word: word,
                            isCompleted: viewModel.isWordCompleted(word.id)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(viewModel.isWordCompleted(word.id)
                                       ? String(localized: "a11y.today.row.review")
                                       : String(localized: "a11y.today.row.practice"))
                }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
    }

    @ViewBuilder
    private func wordDestination(wordId: UUID) -> some View {
        if let progress = userProgress,
           let word = viewModel.wordsById[wordId] {
            WordFeynmanScreen(
                word: word,
                userProgress: progress,
                isCompleted: viewModel.isWordCompleted(wordId),
                latestExplanation: viewModel.latestExplanation(for: wordId, userProgress: progress),
                nextUndoneWord: viewModel.nextUndoneWord(after: wordId),
                onSubmit: { id, explanation, method, markAsMastered in
                    submit(wordId: id, explanation: explanation, method: method, markAsMastered: markAsMastered, progress: progress)
                },
                onAdvanceToNext: { nextId in
                    // Replace top of stack with the next word.
                    path = [nextId]
                }
            )
        }
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

/// A single row in the Today list. Number on the left so the daily set has a
/// rhythm; word + pronunciation in the middle; completion seal on the right.
struct TodayWordRow: View {
    @Environment(\.theme) private var theme

    let number: Int
    let word: Word
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            ZStack {
                Circle()
                    .fill(isCompleted ? theme.colors.accentBg : theme.colors.surfaceAlt)
                    .frame(width: 32, height: 32)
                Text("\(number)")
                    .font(TypographyTokens.mono)
                    .foregroundColor(isCompleted ? theme.colors.accent : theme.colors.inkMuted)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(word.word)
                    .font(TypographyTokens.headline)
                    .foregroundColor(isCompleted ? theme.colors.inkMuted : theme.colors.ink)
                Text(word.pronunciation)
                    .font(TypographyTokens.mono)
                    .foregroundColor(theme.colors.inkFaint)
            }

            Spacer()

            if isCompleted {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18))
                    .foregroundColor(theme.colors.good)
                    .symbolEffect(.bounce, value: isCompleted)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.colors.inkFaint)
                    .accessibilityHidden(true)
            }
        }
        .padding(theme.spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.surface)
        .clipShape(.rect(cornerRadius: RadiusTokens.card))
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .stroke(theme.colors.line, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(word.word). \(isCompleted ? String(localized: "a11y.completed") : "")")
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
