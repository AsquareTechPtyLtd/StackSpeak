import SwiftUI
import SwiftData

/// Review — Assessment + Flashcards.
///
/// R1 — custom hand-rolled segmented control replaced with native
///   `Picker(.segmented)` placed in the navigation toolbar.
/// R2 — stats card-bar removed; the same data lives in a quiet mono caption
///   at the top of the deck.
/// R3 — empty states use the shared `EmptyStateView` and offer a back-to-Today
///   action so they're a launchpad, not a dead end.
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
                content
            }
            .navigationTitle("review.navTitle")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("review.modeLabel", selection: $selectedTab) {
                        Text("review.tab.assessment").tag(ReviewTab.assessment)
                        Text("review.tab.flashcards").tag(ReviewTab.flashcards)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280)
                }
            }
            .task {
                if let progress = userProgress, let services {
                    viewModel.loadDueReviews(progress: progress)
                    await viewModel.loadWords(wordService: services.word)
                    await viewModel.loadEligibleAssessmentWords(wordService: services.word, userProgress: progress)
                }
            }
            .sheet(item: $levelUpDestination) { item in
                if let progress = userProgress {
                    LevelUpView(newLevel: item.level, userProgress: progress)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .assessment: assessmentSection
        case .flashcards: flashcardsSection
        }
    }

    // MARK: - Assessment

    @ViewBuilder
    private var assessmentSection: some View {
        if viewModel.assessmentLoaded, !viewModel.eligibleAssessmentWords.isEmpty {
            assessmentCardsView
        } else if !viewModel.assessmentLoaded || (userProgress?.wordsPracticedIds.isEmpty ?? true) {
            EmptyStateView(
                icon: "checkmark.circle",
                title: "review.assessment.empty.title",
                message: "review.assessment.empty.message"
            )
        } else {
            EmptyStateView(
                icon: "checkmark.seal",
                title: "review.assessment.doneForToday.title",
                message: "review.assessment.doneForToday.message"
            )
        }
    }

    private var assessmentCardsView: some View {
        VStack(spacing: 0) {
            if let progress = userProgress {
                assessmentStatsCaption(progress: progress)
                    .padding(.horizontal, theme.spacing.lg)
                    .padding(.top, theme.spacing.sm)

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
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
    }

    /// R2 — quiet caption replaces the surface-tinted stats bar.
    private func assessmentStatsCaption(progress: UserProgress) -> some View {
        let left = String(format: String(localized: "review.stats.ofCount.format"),
                          viewModel.currentAssessmentIndex + 1,
                          viewModel.eligibleAssessmentWords.count)
        let right = viewModel.eligibleAssessmentWords[safe: viewModel.currentAssessmentIndex].map {
            String(format: String(localized: "review.stats.correctCount.format"),
                   progress.correctAssessmentCount(for: $0.id))
        }
        return statsHStack(left: left, right: right)
    }

    // MARK: - Flashcards

    @ViewBuilder
    private var flashcardsSection: some View {
        if viewModel.dueReviews.isEmpty {
            EmptyStateView(
                icon: "brain",
                title: "review.flashcard.empty.title",
                message: "review.flashcard.empty.message"
            )
        } else {
            reviewCardsView
        }
    }

    private var reviewCardsView: some View {
        VStack(spacing: 0) {
            statsCaption
                .padding(.horizontal, theme.spacing.lg)
                .padding(.top, theme.spacing.sm)

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
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    private var statsCaption: some View {
        let left = String(format: String(localized: "review.stats.ofCount.format"),
                          viewModel.currentIndex + 1, viewModel.dueReviews.count)
        let right = userProgress.map {
            String(format: String(localized: "review.stats.reviewedToday.format"),
                   viewModel.reviewedTodayCount(userProgress: $0))
        }
        return statsHStack(left: left, right: right)
    }

    private func statsHStack(left: String, right: String?) -> some View {
        HStack {
            Text(left)
                .font(TypographyTokens.mono)
                .foregroundColor(theme.colors.inkMuted)
            Spacer()
            if let right {
                Text(right)
                    .font(TypographyTokens.mono)
                    .foregroundColor(theme.colors.inkMuted)
            }
        }
    }

    // MARK: - Handlers

    private func handleReview(reviewState: ReviewState, quality: ReviewQuality) {
        try? services?.reviewScheduler.recordReview(reviewState: reviewState, quality: quality)

        if viewModel.currentIndex < viewModel.dueReviews.count - 1 {
            withAnimation(MotionTokens.standard) { viewModel.currentIndex += 1 }
        } else if let progress = userProgress {
            viewModel.loadDueReviews(progress: progress)
        }
    }

    private func handleAssessmentComplete(isCorrect: Bool, leveledUpTo: Int?, progress: UserProgress) {
        if let newLevel = leveledUpTo {
            levelUpDestination = LevelUpItem(level: newLevel)
        }

        if viewModel.currentAssessmentIndex < viewModel.eligibleAssessmentWords.count - 1 {
            withAnimation(MotionTokens.standard) { viewModel.currentAssessmentIndex += 1 }
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

enum ReviewTab: Hashable {
    case assessment
    case flashcards
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
