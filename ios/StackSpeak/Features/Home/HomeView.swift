import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Query private var userProgressList: [UserProgress]

    @StateObject private var viewModel: HomeViewModel

    init() {
        _viewModel = StateObject(wrappedValue: HomeViewModel())
    }

    var userProgress: UserProgress? {
        userProgressList.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: theme.spacing.cardGap(density: theme.density)) {
                        if let progress = userProgress {
                            headerSection(progress: progress)
                                .padding(.bottom, theme.spacing.md)

                            ForEach(viewModel.todaysWords) { word in
                                WordCardView(
                                    word: word,
                                    isCompleted: viewModel.isWordCompleted(word.id),
                                    userProgress: progress
                                )
                            }
                        }
                    }
                    .padding(theme.spacing.lg)
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .task {
                if let progress = userProgress {
                    await viewModel.loadTodaysWords(modelContext: modelContext, userProgress: progress)
                }
            }
        }
    }

    private func headerSection(progress: UserProgress) -> some View {
        VStack(spacing: theme.spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    if let levelDef = LevelDefinition.definition(for: progress.level) {
                        Text("Level \(progress.level) · \(levelDef.title)")
                            .font(TypographyTokens.headline)
                            .foregroundColor(theme.colors.ink)
                    }

                    if let levelProgress = LevelDefinition.progressToNextLevel(
                        currentLevel: progress.level,
                        wordsAssessedCorrectlyTwice: progress.wordsAssessedCorrectlyTwice
                    ) {
                        ProgressView(value: levelProgress.progress)
                            .tint(theme.colors.accent)

                        Text("\(Int(levelProgress.progress * 100))% • \(levelProgress.wordsRemaining) words to level up")
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
                        Text("\(progress.currentStreak)")
                            .font(TypographyTokens.headline)
                            .foregroundColor(theme.colors.ink)
                    }
                    Text("day streak")
                        .font(TypographyTokens.caption)
                        .foregroundColor(theme.colors.inkMuted)
                }
            }
            .padding(theme.spacing.cardPadding(density: theme.density))
            .background(theme.colors.surface)
            .cornerRadius(12)
        }
    }
}
