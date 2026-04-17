import SwiftUI
import SwiftData

struct AssessmentView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Query private var userProgressList: [UserProgress]

    let word: Word
    let onComplete: (Bool) -> Void

    @State private var selectedAnswer: String?
    @State private var hasSubmitted = false
    @State private var options: [String] = []

    var userProgress: UserProgress? {
        userProgressList.first
    }

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
        .task {
            generateOptions()
        }
    }

    private var questionSection: some View {
        VStack(spacing: theme.spacing.md) {
            Text("What does this word mean?")
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)

            Text(word.word)
                .font(TypographyTokens.title1)
                .foregroundColor(theme.colors.ink)

            Text(word.pronunciation)
                .font(TypographyTokens.mono)
                .foregroundColor(theme.colors.inkMuted)
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

                Text(isCorrect ? "Correct!" : "Not quite")
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.ink)
            }

            if !isCorrect {
                Text("You can try again tomorrow")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
            }

            Button(action: { onComplete(isCorrect) }) {
                Text("Continue")
                    .font(TypographyTokens.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacing.lg)
                    .background(theme.colors.accent)
                    .cornerRadius(12)
            }
        }
        .padding(theme.spacing.md)
        .background(isCorrect ? theme.colors.good.opacity(0.1) : theme.colors.warn.opacity(0.1))
        .cornerRadius(12)
    }

    private var submitButton: some View {
        Button(action: submit) {
            Text("Submit")
                .font(TypographyTokens.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.lg)
                .background(selectedAnswer == nil ? theme.colors.inkFaint : theme.colors.accent)
                .cornerRadius(12)
        }
        .disabled(selectedAnswer == nil)
    }

    private func selectOption(_ option: String) {
        guard !hasSubmitted else { return }
        selectedAnswer = option
    }

    private func submit() {
        guard let selected = selectedAnswer, let progress = userProgress else { return }

        hasSubmitted = true

        let progressService = ProgressService(modelContext: modelContext)
        let leveledUp = progressService.recordAssessmentResult(
            wordId: word.id,
            isCorrect: isCorrect,
            selectedAnswer: selected,
            correctAnswer: word.shortDefinition,
            userProgress: progress
        )

        try? modelContext.save()

        if leveledUp {
            showLevelUpModal()
        }
    }

    private func showLevelUpModal() {
        guard let progress = userProgress else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Level up modal will be shown by parent view
        }
    }

    private func generateOptions() {
        let descriptor = FetchDescriptor<Word>()
        guard let allWords = try? modelContext.fetch(descriptor) else { return }

        let otherWords = allWords.filter { $0.id != word.id }
        let distractors = otherWords.shuffled().prefix(3).map { $0.shortDefinition }

        var allOptions = [word.shortDefinition] + Array(distractors)
        allOptions.shuffle()

        options = allOptions
    }
}

struct OptionButton: View {
    @Environment(\.theme) private var theme

    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let isIncorrect: Bool
    let onTap: () -> Void

    var borderColor: Color {
        if isCorrect {
            return theme.colors.good
        } else if isIncorrect {
            return theme.colors.warn
        } else if isSelected {
            return theme.colors.accent
        } else {
            return theme.colors.line
        }
    }

    var backgroundColor: Color {
        if isCorrect {
            return theme.colors.good.opacity(0.1)
        } else if isIncorrect {
            return theme.colors.warn.opacity(0.1)
        } else if isSelected {
            return theme.colors.accentBg
        } else {
            return theme.colors.surface
        }
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
                    Image(systemName: "checkmark.circle.fill")
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
    }
}
