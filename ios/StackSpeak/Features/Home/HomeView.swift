import SwiftUI
import UIKit
import UserNotifications

struct HomeView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.userProgress) private var userProgress

    @State private var viewModel = HomeViewModel()
    @State private var notificationAuthStatus: UNAuthorizationStatus = .notDetermined
    @State private var showNotificationBanner = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: theme.spacing.cardGap(density: theme.density)) {
                        if let progress = userProgress {
                            // Show notification banner if denied and user has practiced at least once
                            if showNotificationBanner && notificationAuthStatus == .denied && !progress.wordsPracticedIds.isEmpty {
                                notificationBanner
                                    .padding(.bottom, theme.spacing.md)
                            }

                            headerSection(progress: progress)
                                .padding(.bottom, theme.spacing.md)

                            ForEach(viewModel.todaysWords) { word in
                                WordCardView(
                                    word: word,
                                    isCompleted: viewModel.isWordCompleted(word.id),
                                    userProgress: progress
                                )
                            }

                            if viewModel.todaysWords.isEmpty && viewModel.errorMessage == nil {
                                allMasteredState
                            }
                        }
                    }
                    .frame(maxWidth: 720)
                    .padding(theme.spacing.lg)
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
            .navigationTitle("home.navTitle")
            .navigationBarTitleDisplayMode(.large)
            .task {
                if let progress = userProgress, let services {
                    await viewModel.loadTodaysWords(wordService: services.word, userProgress: progress)
                }
                await checkNotificationStatus()
            }
            .onChange(of: userProgress?.masteredWordIds) { _, _ in
                // Refresh list when words are marked as mastered
                Task {
                    if let progress = userProgress, let services {
                        await viewModel.loadTodaysWords(wordService: services.word, userProgress: progress)
                    }
                }
            }
        }
    }

    private func headerSection(progress: UserProgress) -> some View {
        VStack(spacing: theme.spacing.md) {
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
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private var allMasteredState: some View {
        VStack(spacing: theme.spacing.lg) {
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
        }
        .padding(.top, theme.spacing.xxxl)
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

    private func checkNotificationStatus() async {
        guard let services else { return }
        notificationAuthStatus = await services.notification.checkAuthorizationStatus()
        // Show banner if denied and user hasn't explicitly dismissed it for this session
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
