import SwiftUI
import SwiftData
import UserNotifications

struct SentencePracticeView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let word: Word
    let userProgress: UserProgress

    @State private var sentence = ""
    @State private var inputMethod: InputMethod = .typed
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var showNotificationPrompt = false

    private var speechService: any SpeechRepository {
        services?.speech ?? SpeechService()
    }

    var body: some View {
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.xl) {
                    instructionSection
                    inputSection

                    if let error = errorMessage {
                        errorView(error)
                    }

                    submitButton
                }
                .padding(theme.spacing.lg)
            }
        }
        .navigationTitle("practice.navTitle")
        .navigationBarTitleDisplayMode(.inline)
        .alert("practice.success.title", isPresented: $showSuccess) {
            Button("practice.success.continue") {
                dismiss()
                // Show notification prompt after first practice if needed
                if shouldShowNotificationPrompt() {
                    showNotificationPrompt = true
                }
            }
        } message: {
            Text(String(format: String(localized: "practice.success.message.format"), word.word))
        }
        .alert("notifications.prompt.title", isPresented: $showNotificationPrompt) {
            Button("notifications.prompt.enable") {
                Task {
                    if let services {
                        _ = try? await services.notification.requestAuthorization()
                    }
                }
            }
            Button("notifications.prompt.notNow", role: .cancel) { }
        } message: {
            Text("notifications.prompt.message")
        }
    }

    private var instructionSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text(String(format: String(localized: "practice.instruction.format"), word.word))
                .font(TypographyTokens.title2)
                .foregroundColor(theme.colors.ink)

            Text(word.shortDefinition)
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack {
                Text("practice.input.title")
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.ink)

                Spacer()

                if speechService.authorizationStatus == .authorized {
                    Button(action: toggleRecording) {
                        Image(systemName: speechService.isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 20))
                            .foregroundColor(speechService.isRecording ? theme.colors.accent : theme.colors.inkMuted)
                            .padding(theme.spacing.sm)
                            .background(theme.colors.accentBg)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(speechService.isRecording ? "Stop recording" : "Start voice input")
                }
            }

            TextEditor(text: $sentence)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
                .frame(minHeight: 120)
                .padding(theme.spacing.md)
                .background(theme.colors.surfaceAlt)
                .cornerRadius(8)
                .accessibilityLabel(String(localized: "a11y.sentenceInput"))
                .onChange(of: speechService.transcript) { _, newValue in
                    if !newValue.isEmpty {
                        sentence = newValue
                        inputMethod = .voice
                    }
                }
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.colors.warn)

            Text(message)
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.ink)
        }
        .padding(theme.spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.warn.opacity(0.1))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: String(localized: "a11y.error.format"), message))
    }

    private var submitButton: some View {
        Button(action: submit) {
            Text("practice.submit")
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.accentText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.lg)
                .background(sentence.isEmpty ? theme.colors.inkFaint : theme.colors.accent)
                .cornerRadius(12)
        }
        .disabled(sentence.isEmpty)
        .accessibilityLabel(String(localized: "a11y.submitSentence"))
        .accessibilityHint(sentence.isEmpty ? "Type or speak a sentence first" : "")
    }

    private func toggleRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            Task { @MainActor in
                if speechService.authorizationStatus == .notDetermined {
                    _ = await speechService.requestAuthorization()
                }
                guard speechService.authorizationStatus == .authorized else { return }
                do {
                    try speechService.startRecording()
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func submit() {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = String(localized: "practice.error.empty")
            return
        }

        guard containsWord(trimmed, target: word.word) else {
            errorMessage = String(format: String(localized: "practice.error.noWord.format"), word.word)
            return
        }

        guard let services else { return }

        services.progress.markWordPracticed(
            wordId: word.id,
            sentence: trimmed,
            inputMethod: inputMethod,
            userProgress: userProgress
        )

        if let dailySet = try? fetchTodaysDailySet() {
            dailySet.markWordCompleted(word.id)
            if dailySet.isComplete {
                try? services.progress.completeDailySet(dailySet, userProgress: userProgress)
            }
        }

        showSuccess = true
    }

    /// Whole-word match allowing common inflections (plural -s/-es/-ies, past -ed, progressive -ing).
    /// Note: doesn't handle y→ies stem change (query→queries), but matches most CS vocab which pluralizes regularly.
    private func containsWord(_ sentence: String, target: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: target)
        let pattern = "\\b\(escaped)(s|es|ies|ed|ing|'s)?\\b"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(sentence.startIndex..., in: sentence)
        return regex?.firstMatch(in: sentence, range: range) != nil
    }

    private func fetchTodaysDailySet() throws -> DailySet? {
        let today = DailySet.todayString()
        let descriptor = FetchDescriptor<DailySet>(
            predicate: #Predicate { $0.dayString == today }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func shouldShowNotificationPrompt() -> Bool {
        // Show prompt after first practice if notifications not configured
        return userProgress.wordsPracticedIds.count == 1 && !userProgress.notificationEnabled
    }
}
