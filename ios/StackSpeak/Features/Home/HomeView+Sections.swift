import SwiftUI
import SwiftData

// Section builders for HomeView — split out per the <TypeName>+<Concern>.swift
// convention. Stored properties + body remain in HomeView.swift.
extension HomeView {
    /// Compact badge showing today's completion (e.g., "0/5").
    var dayCounterBadge: some View {
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
    func lastTenDays() -> [CompletionDay] {
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
    var sectionDivider: some View {
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
    var instructionLine: some View {
        Text("home.instruction")
            .font(TypographyTokens.subheadline)
            .foregroundColor(theme.colors.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The day's 5 words as a vertical list of tappable rows.
    func wordList(progress: UserProgress) -> some View {
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
    func wordDestination(wordId: UUID) -> some View {
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

}
