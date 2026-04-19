import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.userProgress) private var userProgress

    @State private var viewModel = ReviewViewModel()
    @State private var selectedTab: ReviewTab = .assessment
    @State private var levelUpDestination: LevelUpItem?

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    tabSelector

                    switch selectedTab {
                    case .assessment: assessmentSection
                    case .flashcards: flashcardsSection
                    }
                }
            }
            .navigationTitle("review.navTitle")
            .navigationBarTitleDisplayMode(.large)
            .task {
                if let progress = userProgress, let services {
                    viewModel.loadDueReviews(progress: progress)
                    await viewModel.loadWords(wordService: services.word)
                }
            }
            .sheet(item: $levelUpDestination) { item in
                if let progress = userProgress {
                    LevelUpView(newLevel: item.level, userProgress: progress)
                }
            }
        }
    }

    // MARK: - Tab selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(title: String(localized: "review.tab.assessment"), isSelected: selectedTab == .assessment) {
                selectedTab = .assessment
            }
            TabButton(title: String(localized: "review.tab.flashcards"), isSelected: selectedTab == .flashcards) {
                selectedTab = .flashcards
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top, theme.spacing.sm)
        .background(theme.colors.surface)
    }

    // MARK: - Assessment

    private var assessmentSection: some View {
        Group {
            if let progress = userProgress, !progress.wordsEligibleForAssessment().isEmpty {
                assessmentCardsView
            } else {
                emptyState(
                    icon: "checkmark.circle",
                    title: String(localized: "review.assessment.empty.title"),
                    message: String(localized: "review.assessment.empty.message")
                )
            }
        }
    }

    private var assessmentCardsView: some View {
        VStack(spacing: 0) {
            if let progress = userProgress {
                assessmentStatsHeader(progress: progress)

                TabView(selection: $viewModel.currentAssessmentIndex) {
                    ForEach(Array(viewModel.eligibleAssessmentWords.enumerated()), id: \.offset) { index, word in
                        AssessmentView(word: word) { isCorrect, leveledUpTo in
                            handleAssessmentComplete(isCorrect: isCorrect, leveledUpTo: leveledUpTo, progress: progress)
                        }
                        .id("\(word.id)-\(viewModel.assessmentGeneration)")
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .task {
            if let progress = userProgress, let services {
                await viewModel.loadEligibleAssessmentWords(wordService: services.word, userProgress: progress)
            }
        }
    }

    private func assessmentStatsHeader(progress: UserProgress) -> some View {
        HStack {
            if !viewModel.eligibleAssessmentWords.isEmpty {
                Text(String(format: String(localized: "review.stats.ofCount.format"),
                            viewModel.currentAssessmentIndex + 1, viewModel.eligibleAssessmentWords.count))
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.ink)
            }

            Spacer()

            if let currentWord = viewModel.eligibleAssessmentWords[safe: viewModel.currentAssessmentIndex] {
                let correct = progress.correctAssessmentCount(for: currentWord.id)
                Text(String(format: String(localized: "review.stats.correctCount.format"), correct))
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
            }
        }
        .padding(theme.spacing.lg)
        .background(theme.colors.surface)
    }

    // MARK: - Flashcards

    private var flashcardsSection: some View {
        Group {
            if viewModel.dueReviews.isEmpty {
                emptyState(
                    icon: "brain",
                    title: String(localized: "review.flashcard.empty.title"),
                    message: String(localized: "review.flashcard.empty.message")
                )
            } else {
                reviewCardsView
            }
        }
    }

    private var reviewCardsView: some View {
        VStack(spacing: 0) {
            statsHeader

            TabView(selection: $viewModel.currentIndex) {
                ForEach(Array(viewModel.dueReviews.enumerated()), id: \.element.wordId) { index, reviewState in
                    if let word = viewModel.words[reviewState.wordId] {
                        FlashcardView(
                            word: word,
                            onAgain: { handleReview(reviewState: reviewState, quality: .again) },
                            onGood:  { handleReview(reviewState: reviewState, quality: .good) }
                        )
                        .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    private var statsHeader: some View {
        HStack {
            Text(String(format: String(localized: "review.stats.ofCount.format"),
                        viewModel.currentIndex + 1, viewModel.dueReviews.count))
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.ink)

            Spacer()

            if let progress = userProgress {
                Text(String(format: String(localized: "review.stats.reviewedToday.format"),
                            viewModel.reviewedTodayCount(userProgress: progress)))
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
            }
        }
        .padding(theme.spacing.lg)
        .background(theme.colors.surface)
    }

    // MARK: - Empty state

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: theme.spacing.lg) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 64, weight: .light))
                .foregroundColor(theme.colors.inkFaint)
            Text(title)
                .font(TypographyTokens.title2)
                .foregroundColor(theme.colors.ink)
            Text(message)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.xxxl)
            Spacer()
        }
    }

    // MARK: - Handlers

    private func handleReview(reviewState: ReviewState, quality: ReviewQuality) {
        try? services?.reviewScheduler.recordReview(reviewState: reviewState, quality: quality)

        if viewModel.currentIndex < viewModel.dueReviews.count - 1 {
            withAnimation { viewModel.currentIndex += 1 }
        } else if let progress = userProgress {
            viewModel.loadDueReviews(progress: progress)
        }
    }

    private func handleAssessmentComplete(isCorrect: Bool, leveledUpTo: Int?, progress: UserProgress) {
        if let newLevel = leveledUpTo {
            levelUpDestination = LevelUpItem(level: newLevel)
        }

        if viewModel.currentAssessmentIndex < viewModel.eligibleAssessmentWords.count - 1 {
            withAnimation { viewModel.currentAssessmentIndex += 1 }
        } else {
            Task {
                if let services {
                    await viewModel.loadEligibleAssessmentWords(wordService: services.word, userProgress: progress)
                }
            }
        }
    }
}

// MARK: - Supporting types

enum ReviewTab {
    case assessment
    case flashcards
}

struct TabButton: View {
    @Environment(\.theme) private var theme

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: theme.spacing.xs) {
                Text(title)
                    .font(TypographyTokens.callout.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? theme.colors.accent : theme.colors.inkMuted)

                Rectangle()
                    .fill(isSelected ? theme.colors.accent : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, theme.spacing.xs)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct LevelUpItem: Identifiable {
    let level: Int
    var id: Int { level }
}

#Preview("Review - Light") {
    ReviewView()
        .withTheme(ThemeManager())
}

#Preview("Review - Dark") {
    ReviewView()
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
