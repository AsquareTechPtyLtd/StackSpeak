import SwiftUI
import SwiftData

struct AssessmentView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext

    let word: Word
    /// Called when the user taps Continue. `leveledUpTo` is non-nil when this answer triggered a level-up.
    let onComplete: (_ isCorrect: Bool, _ leveledUpTo: Int?) -> Void

    @State private var selectedAnswer: String?
    @State private var hasSubmitted = false
    @State private var options: [String] = []
    @State private var pendingLevelUp: Int?

    private static let distractorCount = 3

    var isCorrect: Bool {
        selectedAnswer == word.shortDefinition
    }

    var body: some View {
        VStack(spacing: theme.spacing.xl) {
            Spacer()

            questionSection

            optionsSection

            Spacer()

            if hasSubmitted {
                feedbackSection
            } else {
                submitButton
            }
        }
        .padding(theme.spacing.lg)
        // Generate options once per word, not on every re-appear.
        .task(id: word.id) {
            if options.isEmpty {
                generateOptions()
            }
        }
    }

    // MARK: - Sections

    private var questionSection: some View {
        VStack(spacing: theme.spacing.md) {
            Text("review.assessment.question")
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)

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
                    isCorrect: hasSubmitted && option == word.shortDefinition,
                    isIncorrect: hasSubmitted && selectedAnswer == option && option != word.shortDefinition,
                    onTap: { selectOption(option) }
                )
            }
        }
    }

    private var feedbackSection: some View {
        VStack(spacing: theme.spacing.md) {
            HStack(spacing: theme.spacing.md) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isCorrect ? theme.colors.good : theme.colors.warn)

                Text(isCorrect
                     ? String(localized: "review.assessment.correct")
                     : String(localized: "review.assessment.incorrect"))
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.ink)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isCorrect ? String(localized: "review.assessment.correct") : String(localized: "review.assessment.incorrect"))

            if !isCorrect {
                Text("review.assessment.tryAgain")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
            }

            Button(action: { onComplete(isCorrect, pendingLevelUp) }) {
                Text("review.assessment.continue")
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.accentText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacing.lg)
                    .background(theme.colors.accent)
                    .cornerRadius(12)
            }
            .accessibilityLabel(String(localized: "a11y.continueNext"))
        }
        .padding(theme.spacing.md)
        .background(isCorrect ? theme.colors.good.opacity(0.1) : theme.colors.warn.opacity(0.1))
        .cornerRadius(12)
    }

    private var submitButton: some View {
        Button(action: submit) {
            Text("review.assessment.submit")
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.accentText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.lg)
                .background(selectedAnswer == nil ? theme.colors.inkFaint : theme.colors.accent)
                .cornerRadius(12)
        }
        .disabled(selectedAnswer == nil)
        .accessibilityLabel(String(localized: "a11y.submitAnswer"))
        .accessibilityHint(selectedAnswer == nil ? "Select a definition first" : "Tap to submit your answer")
    }

    // MARK: - Actions

    private func selectOption(_ option: String) {
        guard !hasSubmitted else { return }
        selectedAnswer = option
    }

    private func submit() {
        guard let selected = selectedAnswer, let progress = userProgress, let services else { return }

        hasSubmitted = true

        let newLevel = services.progress.recordAssessmentResult(
            wordId: word.id,
            isCorrect: isCorrect,
            selectedAnswer: selected,
            correctAnswer: word.shortDefinition,
            userProgress: progress
        )

        // recordAssessmentResult already saves via ProgressService

        // Deliver level-up immediately so it's not lost if user swipes past Continue
        pendingLevelUp = newLevel
        if let newLevel = newLevel {
            onComplete(isCorrect, newLevel)
        }
    }

    // MARK: - Options generation

    private func generateOptions() {
        guard let progress = userProgress else { return }

        let descriptor = FetchDescriptor<Word>()
        guard let allWords = try? modelContext.fetch(descriptor) else { return }

        // Distractors from words the user has practiced (more plausible); fall back to any unlocked word.
        let practicedDistractors = allWords.filter {
            $0.id != word.id &&
            progress.wordsPracticedIds.contains($0.id) &&
            $0.shortDefinition != word.shortDefinition
        }

        let fallbackPool = allWords.filter {
            $0.id != word.id &&
            $0.unlockLevel <= progress.level &&
            $0.shortDefinition != word.shortDefinition
        }

        let pool = practicedDistractors.count >= Self.distractorCount ? practicedDistractors : fallbackPool
        let distractors = pool.shuffled().prefix(Self.distractorCount).map { $0.shortDefinition }

        var allOptions = [word.shortDefinition] + Array(distractors)
        // Deduplicate in case definitions overlap.
        allOptions = Array(NSOrderedSet(array: allOptions)) as? [String] ?? allOptions
        allOptions.shuffle()

        options = allOptions
    }
}

// MARK: - OptionButton

struct OptionButton: View {
    @Environment(\.theme) private var theme

    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let isIncorrect: Bool
    let onTap: () -> Void

    var borderColor: Color {
        if isCorrect   { return theme.colors.good }
        if isIncorrect { return theme.colors.warn }
        if isSelected  { return theme.colors.accent }
        return theme.colors.line
    }

    var backgroundColor: Color {
        if isCorrect   { return theme.colors.good.opacity(0.1) }
        if isIncorrect { return theme.colors.warn.opacity(0.1) }
        if isSelected  { return theme.colors.accentBg }
        return theme.colors.surface
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(text)
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.ink)
                    .multilineTextAlignment(.leading)

                Spacer()

                if isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.colors.good)
                } else if isIncorrect {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.colors.warn)
                } else if isSelected {
                    Image(systemName: "circle.fill")
                        .foregroundColor(theme.colors.accent)
                }
            }
            .padding(theme.spacing.md)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: isSelected || isCorrect || isIncorrect ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isCorrect || isIncorrect)
        .accessibilityLabel(text)
        .accessibilityValue(isCorrect ? "correct" : isIncorrect ? "incorrect" : isSelected ? "selected" : "")
    }
}
