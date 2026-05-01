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

    @Query private var dailySets: [DailySet]
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
                    dayCounterBadge()
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
                sectionDivider()
                    .padding(.horizontal, theme.spacing.lg)

                CompletionTrackerRow(days: lastTenDays())
                    .padding(.horizontal, theme.spacing.lg)

                sectionDivider()
                    .padding(.horizontal, theme.spacing.lg)

                instructionLine()
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

    /// Compact badge showing today's completion (e.g., "0/5").
    private func dayCounterBadge() -> some View {
        let total = viewModel.dailySet?.wordIds.count ?? 0
        let done = (viewModel.dailySet?.wordIds ?? [])
            .filter { viewModel.isWordCompleted($0) }
            .count

        return HStack(spacing: 4) {
            Text("\(done)")
                .font(TypographyTokens.mono.weight(.semibold))
                .foregroundColor(done == total && total > 0 ? theme.colors.good : theme.colors.ink)
                .contentTransition(.numericText())
            Text("/")
                .font(TypographyTokens.mono)
                .foregroundColor(theme.colors.inkFaint)
            Text("\(total)")
                .font(TypographyTokens.mono)
                .foregroundColor(theme.colors.inkMuted)
        }
        .padding(.horizontal, theme.spacing.sm)
        .padding(.vertical, theme.spacing.xs)
        .background(theme.colors.surfaceAlt)
        .clipShape(.rect(cornerRadius: RadiusTokens.inline))
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.inline)
                .stroke(theme.colors.line, lineWidth: 0.5)
        )
    }

    /// Returns the last 10 calendar days (oldest → today) with the day's
    /// daily-set progress (0...1). Drives the tracker strip beneath the
    /// counter.
    private func lastTenDays() -> [CompletionDay] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let setsByDay = Dictionary(uniqueKeysWithValues: dailySets.map { ($0.dayString, $0) })
        return (0..<10).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let key = DailySet.dayString(from: date)
            let progress = setsByDay[key]?.progress ?? 0
            let isToday = offset == 0
            return CompletionDay(date: date, progress: progress, isToday: isToday)
        }
    }

    /// Subtle decorative divider — thin gradient fade for gentle section breaks.
    private func sectionDivider() -> some View {
        LinearGradient(
            colors: [
                theme.colors.line.opacity(0),
                theme.colors.lineStrong,
                theme.colors.lineStrong,
                theme.colors.line.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
        .padding(.vertical, theme.spacing.xs)
    }

    /// Quiet instruction that does what the dropped `.word` stage used to do —
    /// asks the user to say each word aloud before tapping into the deeper flow.
    private func instructionLine() -> some View {
        Text("home.instruction")
            .font(TypographyTokens.subheadline)
            .foregroundColor(theme.colors.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                onSubmit: { id, explanation, method, markAsMastered in
                    submit(wordId: id, explanation: explanation, method: method, markAsMastered: markAsMastered, progress: progress)
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
                    .font(.system(.caption))
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
                    .font(isCompleted
                          ? TypographyTokens.body.weight(.regular)
                          : TypographyTokens.headline)
                    .foregroundColor(isCompleted ? theme.colors.inkMuted : theme.colors.ink)
                    .strikethrough(isCompleted, color: theme.colors.inkFaint)
                Text(word.pronunciation)
                    .font(TypographyTokens.mono)
                    .foregroundColor(theme.colors.inkFaint)
            }

            Spacer()

            if isCompleted {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(.headline))
                    .foregroundColor(theme.colors.good)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(.subheadline, weight: .semibold))
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

// MARK: - 10-day completion tracker

struct CompletionDay: Identifiable {
    let date: Date
    /// 0...1 — fraction of the day's daily set that was practiced.
    let progress: Double
    let isToday: Bool

    var id: Date { date }
    var isComplete: Bool { progress >= 1.0 }
    var hasAnyProgress: Bool { progress > 0 }
}

/// Ten-day streak strip. Each cell stacks a day-of-week initial, a 22pt
/// rounded square that fills bottom-up by completion progress, and the
/// date number. Today is anchored with an accent ring on the cell.
///
/// Design references: Apple Fitness weekly view (day-letter + cell + date),
/// Duolingo streak calendar (warm flame color for filled days, today
/// emphasized), Streaks app (partial fill encodes progress not just
/// done/not-done). Color choice: `streak` (warm amber) ties visually to
/// the flame in the status line above; `good` (green) was reserved for
/// "you got an answer right" elsewhere in the app.
struct CompletionTrackerRow: View {
    @Environment(\.theme) private var theme

    let days: [CompletionDay]

    private static let cellSize: CGFloat = 22
    private static let cellRadius: CGFloat = RadiusTokens.inline

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(days) { day in
                cell(for: day)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private func cell(for day: CompletionDay) -> some View {
        VStack(spacing: 4) {
            Text(dayLetter(for: day.date))
                .font(TypographyTokens.mono)
                .foregroundColor(day.isToday ? theme.colors.accent : theme.colors.inkFaint)

            ZStack(alignment: .bottom) {
                // Empty surface
                RoundedRectangle(cornerRadius: Self.cellRadius)
                    .fill(theme.colors.surfaceAlt)

                // Bottom-up fill proportional to day's completion (Apple Fitness ring vibe).
                if day.hasAnyProgress {
                    RoundedRectangle(cornerRadius: Self.cellRadius)
                        .fill(day.isComplete
                              ? theme.colors.streak
                              : theme.colors.streak.opacity(0.45))
                        .frame(height: Self.cellSize * CGFloat(day.progress))
                }

                if day.isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundColor(theme.colors.streakInk)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: Self.cellSize, height: Self.cellSize)
            .clipShape(.rect(cornerRadius: Self.cellRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Self.cellRadius)
                    .strokeBorder(
                        day.isToday ? theme.colors.accentDecoration
                                    : (day.hasAnyProgress ? theme.colors.streak.opacity(0.8) : theme.colors.line),
                        lineWidth: day.isToday ? 1.5 : 0.5
                    )
            )

            Text(dayNumber(for: day.date))
                .font(TypographyTokens.mono)
                .foregroundColor(day.isToday ? theme.colors.ink : theme.colors.inkFaint)
        }
    }

    // MARK: - Date formatting

    private func dayLetter(for date: Date) -> String {
        // First letter of the localized weekday (e.g. "M", "T", "W").
        // `veryShortWeekdaySymbols` returns single characters per locale.
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols
        let weekdayIndex = cal.component(.weekday, from: date) - 1
        guard weekdayIndex >= 0, weekdayIndex < symbols.count else { return "" }
        return symbols[weekdayIndex]
    }

    private func dayNumber(for date: Date) -> String {
        let cal = Calendar.current
        return "\(cal.component(.day, from: date))"
    }

    private var accessibilitySummary: String {
        let completed = days.filter { $0.isComplete }.count
        return String(format: String(localized: "home.tracker.accessibility.format"),
                      completed, days.count)
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
