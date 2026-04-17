import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Query private var userProgressList: [UserProgress]

    @StateObject private var viewModel = ReviewViewModel()
    @State private var selectedTab: ReviewTab = .assessment

    var userProgress: UserProgress? {
        userProgressList.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    tabSelector

                    switch selectedTab {
                    case .assessment:
                        assessmentSection
                    case .flashcards:
                        flashcardsSection
                    }
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.large)
            .task {
                if let progress = userProgress {
                    viewModel.loadDueReviews(progress: progress)
                    await viewModel.loadWords(from: modelContext)
                }
            }
        }
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "Assessment",
                isSelected: selectedTab == .assessment,
                action: { selectedTab = .assessment }
            )

            TabButton(
                title: "Flashcards",
                isSelected: selectedTab == .flashcards,
                action: { selectedTab = .flashcards }
            )
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top, theme.spacing.sm)
        .background(theme.colors.surface)
    }

    private var assessmentSection: some View {
        Group {
            if let progress = userProgress, !progress.wordsEligibleForAssessment().isEmpty {
                assessmentCardsView
            } else {
                assessmentEmptyState
            }
        }
    }

    private var flashcardsSection: some View {
        Group {
            if viewModel.dueReviews.isEmpty {
                flashcardsEmptyState
            } else {
                reviewCardsView
            }
        }
    }

    private var assessmentEmptyState: some View {
        VStack(spacing: theme.spacing.lg) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(theme.colors.inkFaint)

            Text("No assessments available")
                .font(TypographyTokens.title2)
                .foregroundColor(theme.colors.ink)

            Text("Practice words from today's set to unlock assessments.")
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.xxxl)
        }
    }

    private var flashcardsEmptyState: some View {
        VStack(spacing: theme.spacing.lg) {
            Image(systemName: "brain")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(theme.colors.inkFaint)

            Text("No flashcards due")
                .font(TypographyTokens.title2)
                .foregroundColor(theme.colors.ink)

            Text("Complete today's words to add them to your review queue.")
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.xxxl)
        }
    }

    private var assessmentCardsView: some View {
        VStack(spacing: 0) {
            if let progress = userProgress {
                assessmentStatsHeader(progress: progress)

                TabView(selection: $viewModel.currentAssessmentIndex) {
                    ForEach(Array(viewModel.eligibleAssessmentWords.enumerated()), id: \.offset) { index, word in
                        AssessmentView(word: word) { isCorrect in
                            handleAssessmentComplete(isCorrect: isCorrect, progress: progress)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .task {
            if let progress = userProgress {
                await viewModel.loadEligibleAssessmentWords(modelContext: modelContext, userProgress: progress)
            }
        }
    }

    private var reviewCardsView: some View {
        VStack(spacing: 0) {
            statsHeader

            TabView(selection: $viewModel.currentIndex) {
                ForEach(Array(viewModel.dueReviews.enumerated()), id: \.offset) { index, reviewState in
                    if let word = viewModel.words[reviewState.wordId] {
                        FlashcardView(
                            word: word,
                            onAgain: { handleReview(reviewState: reviewState, quality: .again) },
                            onGood: { handleReview(reviewState: reviewState, quality: .good) }
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
            Text("\(viewModel.currentIndex + 1) of \(viewModel.dueReviews.count)")
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.ink)

            Spacer()

            Text("\(viewModel.reviewedCount) reviewed today")
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
        }
        .padding(theme.spacing.lg)
        .background(theme.colors.surface)
    }

    private func assessmentStatsHeader(progress: UserProgress) -> some View {
        HStack {
            Text("\(viewModel.currentAssessmentIndex + 1) of \(viewModel.eligibleAssessmentWords.count)")
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.ink)

            Spacer()

            Text("\(progress.correctAssessmentCount(for: viewModel.eligibleAssessmentWords[safe: viewModel.currentAssessmentIndex]?.id ?? UUID()))/2 correct")
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
        }
        .padding(theme.spacing.lg)
        .background(theme.colors.surface)
    }

    private func handleReview(reviewState: ReviewState, quality: ReviewQuality) {
        let schedulerService = ReviewSchedulerService(modelContext: modelContext)
        try? schedulerService.recordReview(reviewState: reviewState, quality: quality)

        viewModel.reviewedCount += 1

        if viewModel.currentIndex < viewModel.dueReviews.count - 1 {
            withAnimation {
                viewModel.currentIndex += 1
            }
        } else {
            if let progress = userProgress {
                viewModel.loadDueReviews(progress: progress)
            }
        }
    }

    private func handleAssessmentComplete(isCorrect: Bool, progress: UserProgress) {
        if viewModel.currentAssessmentIndex < viewModel.eligibleAssessmentWords.count - 1 {
            withAnimation {
                viewModel.currentAssessmentIndex += 1
            }
        } else {
            Task {
                await viewModel.loadEligibleAssessmentWords(modelContext: modelContext, userProgress: progress)
            }
        }
    }
}

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
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
