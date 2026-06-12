import Accessibility
import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(category: "AssessmentView")

/// Multiple-choice assessment card for one practiced word. Correct answers
/// auto-advance after a brief read-through; incorrect answers wait for Continue.
struct AssessmentView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.userProgress) var userProgress
    @Environment(\.modelContext) var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    let word: Word
    /// Called when this answer is fully resolved. `leveledUpTo` is non-nil
    /// when this answer triggered a level-up.
    let onComplete: (_ isCorrect: Bool, _ leveledUpTo: Int?) -> Void

    @State private var selectedAnswer: String?
    @State private var hasSubmitted = false
    @State var options: [String] = []
    @State private var pendingLevelUp: Int?
    @State private var feedbackTrigger: FeedbackResult?
    @State private var errorMessage: String?
    @State private var autoAdvanceTask: Task<Void, Never>?
    @State private var showMasteryPrompt = false

    static let distractorCount = 3
    private static let autoAdvanceDelay: Duration = .milliseconds(900)
    /// VoiceOver users get the result announced and a longer beat before the
    /// card advances under them (SC 4.1.3).
    private static let voiceOverAutoAdvanceDelay: Duration = .milliseconds(2500)

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
        .alert(
            Text("saveError.title"),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            presenting: errorMessage
        ) { _ in
            Button("common.ok") { errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
        .onDisappear {
            // The card can be torn down (parent advanced, sheet dismissed) while
            // the auto-advance is pending — firing onComplete then would advance
            // the assessment index a second time and silently skip a word.
            autoAdvanceTask?.cancel()
        }
        // Second correct answer = full credit earned and the word leaves the
        // assessment pool — the natural moment to offer retiring it from the
        // daily rotation too. Either choice advances to the next card.
        .alert("review.mastery.title", isPresented: $showMasteryPrompt) {
            Button("review.mastery.confirm") { markMasteredAndAdvance() }
            Button("review.mastery.keep", role: .cancel) { onComplete(true, nil) }
        } message: {
            Text(String(format: String(localized: "review.mastery.message.format"), word.word))
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
                let levelUp = pendingLevelUp
                pendingLevelUp = nil
                onComplete(isCorrect, levelUp)
            }
        }
    }

    // MARK: - State

    private func stateFor(option: String) -> OptionButton.State {
        guard hasSubmitted else { return .idle }
        if option == word.shortDefinition { return .correct }
        if option == selectedAnswer       { return .incorrect }
        return .idle
    }

    // MARK: - Actions

    /// Tapping an option submits it directly — a separate Submit tap added
    /// friction without preventing any error (options are single-tap final).
    private func selectOption(_ option: String) {
        guard !hasSubmitted else { return }
        selectedAnswer = option
        submit()
    }

    private func submit() {
        guard let selected = selectedAnswer, let progress = userProgress, let services else { return }

        // Persist first: the save is the gate for resolving the UI. If recording
        // the result fails, the card stays editable and shows a retryable error —
        // we never present a resolved/auto-advanced state for an attempt that
        // wasn't durably recorded (assessment is the progression currency).
        let correct = isCorrect
        // Read before recording: already in the first-correct tracker means this
        // correct answer is the word's second — the one that earns level credit.
        let isSecondCorrect = correct && progress.wordsCreditedForLevelIds.contains(word.id)
        let newLevel: Int?
        do {
            newLevel = try services.progress.recordAssessmentResult(
                wordId: word.id,
                isCorrect: correct,
                selectedAnswer: selected,
                correctAnswer: word.shortDefinition,
                userProgress: progress
            )
        } catch {
            logger.error("Failed to record assessment result: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            return
        }

        hasSubmitted = true
        feedbackTrigger = correct ? .correct : .incorrect
        pendingLevelUp = newLevel

        if let newLevel {
            // Level-up takes precedence: hand control to the parent immediately so
            // the celebration sheet appears and isn't lost on auto-advance. Consume
            // the pending value here — leaving it set would let a later Continue
            // tap on this card re-fire the same level-up.
            pendingLevelUp = nil
            onComplete(correct, newLevel)
            return
        }

        // The second correct completes the word's assessment journey — offer to
        // mark it mastered instead of auto-advancing. (When it also triggered a
        // level-up, the celebration above takes precedence and no prompt shows.)
        if isSecondCorrect {
            showMasteryPrompt = true
            return
        }

        // Correct answers auto-advance after a brief read-through. The task is
        // stored so onDisappear can cancel it — see the modifier above.
        if correct {
            autoAdvanceTask?.cancel()
            AccessibilityNotification.Announcement(
                String(localized: "a11y.assessment.correct.autoAdvance")
            ).post()
            let delay = voiceOverEnabled ? Self.voiceOverAutoAdvanceDelay : Self.autoAdvanceDelay
            autoAdvanceTask = Task {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                onComplete(true, nil)
            }
        }
    }

    /// Marks the word mastered (out of daily rotation) and advances. A save
    /// failure is logged but still advances — the assessment result itself was
    /// already durably recorded, and mastery can be retried from the word page.
    private func markMasteredAndAdvance() {
        if let progress = userProgress, let services {
            do {
                try services.progress.markWordMastered(word.id, userProgress: progress)
            } catch {
                logger.error("Failed to mark word mastered: \(error.localizedDescription, privacy: .public)")
            }
        }
        onComplete(true, nil)
    }

    // MARK: - Options generation

    enum FeedbackResult: Equatable {
        case correct, incorrect
    }
}

// MARK: - Previews

private func previewWord() -> Word {
    Word(
        id: UUID(),
        word: "idempotent",
        pronunciation: "/ˌaɪ.dəmˈpoʊ.tənt/",
        partOfSpeech: "adjective",
        shortDefinition: "Producing the same result no matter how many times it's applied.",
        simpleDefinition: "Doing it once or a hundred times gives the same outcome.",
        longDefinition: "An operation is idempotent if applying it multiple times has the same effect as applying it once.",
        techContext: "REST APIs mark GET, PUT, and DELETE as idempotent; POST is generally not.",
        exampleSentence: "A DELETE request is idempotent — deleting a resource twice is the same as deleting it once.",
        etymology: "From Latin idem (same) + potent (powerful).",
        connector: "Think of a light switch that only turns off — pressing it again changes nothing.",
        codeExampleLanguage: "swift",
        codeExampleCode: "func setActive(_ active: Bool) { isActive = active }",
        stack: "basic-web",
        unlockLevel: 1,
        tags: []
    )
}

#Preview("Assessment — Light") {
    AssessmentView(
        word: previewWord(),
        onComplete: { _, _ in }
    )
    .modelContainer(for: [Word.self, UserProgress.self], inMemory: true)
    .environment(\.userProgress, UserProgress())
    .withTheme(ThemeManager())
}

#Preview("Assessment — Dark") {
    AssessmentView(
        word: previewWord(),
        onComplete: { _, _ in }
    )
    .modelContainer(for: [Word.self, UserProgress.self], inMemory: true)
    .environment(\.userProgress, UserProgress())
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}
