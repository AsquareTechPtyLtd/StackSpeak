import SwiftUI
import SwiftData

/// One assessment question.
///
/// A1 — redundant "What does this word mean?" prompt removed (the four
///   definition options are self-evidently the question).
/// A2 — single-signal selection on `OptionButton` (background + border, no
///   triple-stacked icon).
/// A3 — correct answers auto-advance after a brief read-through; incorrect
///   answers stay until Continue is tapped so the user can see the right one.
/// A4 — `.sensoryFeedback` `.success` / `.error` on submit.
struct AssessmentView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let word: Word
    /// Called when this answer is fully resolved. `leveledUpTo` is non-nil
    /// when this answer triggered a level-up.
    let onComplete: (_ isCorrect: Bool, _ leveledUpTo: Int?) -> Void

    @State private var selectedAnswer: String?
    @State private var hasSubmitted = false
    @State private var options: [String] = []
    @State private var pendingLevelUp: Int?
    @State private var feedbackTrigger: FeedbackResult?

    private static let distractorCount = 3
    private static let autoAdvanceDelay: Duration = .milliseconds(900)

    var isCorrect: Bool {
        selectedAnswer == word.shortDefinition
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.xl) {
                questionSection
                optionsSection

                if hasSubmitted && !isCorrect {
                    incorrectFeedback
                } else if !hasSubmitted {
                    submitButton
                }
            }
            .padding(theme.spacing.lg)
        }
        .task(id: word.id) {
            if options.isEmpty {
                generateOptions()
            }
        }
        .sensoryFeedback(trigger: feedbackTrigger) { _, new in
            switch new {
            case .correct: return .success
            case .incorrect: return .error
            case nil: return nil
            }
        }
    }

    // MARK: - Sections

    private var questionSection: some View {
        VStack(spacing: theme.spacing.sm) {
            Text(word.word)
                .font(TypographyTokens.title1)
                .foregroundColor(theme.colors.ink)
                .accessibilityAddTraits(.isHeader)
            Text(word.pronunciation)
                .font(TypographyTokens.mono)
                .foregroundColor(theme.colors.inkMuted)
                .accessibilityLabel(String(format: String(localized: "a11y.pronunciation.format"), word.pronunciation))
        }
    }

    private var optionsSection: some View {
        VStack(spacing: theme.spacing.sm) {
            ForEach(options, id: \.self) { option in
                OptionButton(
                    text: option,
                    isSelected: selectedAnswer == option,
                    state: stateFor(option: option),
                    onTap: { selectOption(option) }
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var incorrectFeedback: some View {
        VStack(spacing: theme.spacing.md) {
            Text("review.assessment.tryAgain")
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
            PrimaryCTAButton("review.assessment.continue") {
                onComplete(isCorrect, pendingLevelUp)
            }
        }
    }

    private var submitButton: some View {
        PrimaryCTAButton("review.assessment.submit") { submit() }
            .disabled(selectedAnswer == nil)
            .accessibilityLabel(String(localized: "a11y.submitAnswer"))
            .accessibilityHint(selectedAnswer == nil ? "Select a definition first" : "Tap to submit your answer")
    }

    // MARK: - State

    private func stateFor(option: String) -> OptionButton.State {
        guard hasSubmitted else { return .idle }
        if option == word.shortDefinition { return .correct }
        if option == selectedAnswer       { return .incorrect }
        return .idle
    }

    // MARK: - Actions

    private func selectOption(_ option: String) {
        guard !hasSubmitted else { return }
        selectedAnswer = option
    }

    private func submit() {
        guard let selected = selectedAnswer, let progress = userProgress, let services else { return }

        hasSubmitted = true
        feedbackTrigger = isCorrect ? .correct : .incorrect

        let newLevel = services.progress.recordAssessmentResult(
            wordId: word.id,
            isCorrect: isCorrect,
            selectedAnswer: selected,
            correctAnswer: word.shortDefinition,
            userProgress: progress
        )
        pendingLevelUp = newLevel

        if let newLevel {
            // Level-up takes precedence: hand control to the parent immediately so
            // the celebration sheet appears and isn't lost on auto-advance.
            onComplete(isCorrect, newLevel)
            return
        }

        // A3 — correct answers auto-advance after a brief read-through.
        if isCorrect {
            Task {
                try? await Task.sleep(for: Self.autoAdvanceDelay)
                onComplete(true, nil)
            }
        }
    }

    // MARK: - Options generation

    private func generateOptions() {
        guard let progress = userProgress,
              let allWords = try? modelContext.fetch(FetchDescriptor<Word>()) else { return }

        let distractors = Self.buildDistractors(for: word, count: Self.distractorCount,
                                                allWords: allWords, progress: progress)
        var allOptions = [word.shortDefinition] + distractors
        allOptions = Array(NSOrderedSet(array: allOptions)) as? [String] ?? allOptions
        allOptions.shuffle()
        options = allOptions
    }

    /// Picks plausible wrong-answer definitions: prefers words the user has practiced,
    /// falls back to any unlocked word at the user's current level.
    private static func buildDistractors(for word: Word, count: Int,
                                         allWords: [Word], progress: UserProgress) -> [String] {
        func excludesTarget(_ w: Word) -> Bool {
            w.id != word.id && w.shortDefinition != word.shortDefinition
        }
        let practiced = allWords.filter { excludesTarget($0) && progress.wordsPracticedIds.contains($0.id) }
        let pool = practiced.count >= count
            ? practiced
            : allWords.filter { excludesTarget($0) && $0.unlockLevel <= progress.level }
        return pool.shuffled().prefix(count).map(\.shortDefinition)
    }

    private enum FeedbackResult: Equatable {
        case correct, incorrect
    }
}

// MARK: - OptionButton

struct OptionButton: View {
    @Environment(\.theme) private var theme

    enum State { case idle, correct, incorrect }

    let text: String
    let isSelected: Bool
    let state: State
    let onTap: () -> Void

    private var border: Color {
        switch state {
        case .correct:   return theme.colors.good
        case .incorrect: return theme.colors.bad
        case .idle:      return isSelected ? theme.colors.accent : theme.colors.line
        }
    }

    private var fill: Color {
        switch state {
        case .correct:   return theme.colors.good.opacity(0.10)
        case .incorrect: return theme.colors.bad.opacity(0.10)
        case .idle:      return isSelected ? theme.colors.accentBg : theme.colors.surface
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top) {
                Text(text)
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: theme.spacing.sm)
            }
            .padding(theme.spacing.md)
            .background(fill)
            .clipShape(.rect(cornerRadius: RadiusTokens.card))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .stroke(border, lineWidth: state != .idle || isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
        .accessibilityLabel(text)
        .accessibilityValue({
            switch state {
            case .correct:   return "correct"
            case .incorrect: return "incorrect"
            case .idle:      return isSelected ? "selected" : ""
            }
        }())
    }
}
