import SwiftUI

struct SentencePracticeView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let word: Word
    let userProgress: UserProgress

    @StateObject private var speechService = SpeechService()
    @State private var sentence = ""
    @State private var inputMethod: InputMethod = .typed
    @State private var errorMessage: String?
    @State private var showSuccess = false

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
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Great work!", isPresented: $showSuccess) {
            Button("Continue") {
                dismiss()
            }
        } message: {
            Text("You've practiced \"\(word.word)\"! Take the assessment in Review to count it toward your level.")
        }
        .task {
            if speechService.authorizationStatus == .notDetermined {
                _ = await speechService.requestAuthorization()
            }
        }
    }

    private var instructionSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Use \"\(word.word)\" in a sentence")
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
                Text("Your sentence")
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
                }
            }

            TextEditor(text: $sentence)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
                .frame(minHeight: 120)
                .padding(theme.spacing.md)
                .background(theme.colors.surfaceAlt)
                .cornerRadius(8)
                .onChange(of: speechService.transcript) { _, newValue in
                    sentence = newValue
                    inputMethod = .voice
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
    }

    private var submitButton: some View {
        Button(action: submit) {
            Text("Submit")
                .font(TypographyTokens.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.lg)
                .background(sentence.isEmpty ? theme.colors.inkFaint : theme.colors.accent)
                .cornerRadius(12)
        }
        .disabled(sentence.isEmpty)
    }

    private func toggleRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            do {
                try speechService.startRecording()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func submit() {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            errorMessage = "Please write a sentence first."
            return
        }

        let containsWord = trimmed.localizedCaseInsensitiveContains(word.word)
        guard containsWord else {
            errorMessage = "Your sentence must contain the word \"\(word.word)\"."
            return
        }

        let progressService = ProgressService(modelContext: modelContext)
        progressService.markWordPracticed(
            wordId: word.id,
            sentence: trimmed,
            inputMethod: inputMethod,
            userProgress: userProgress
        )

        if let dailySet = try? fetchTodaysDailySet() {
            dailySet.markWordCompleted(word.id)

            if dailySet.isComplete {
                try? progressService.completeDailySet(dailySet, userProgress: userProgress)
            }
        }

        try? modelContext.save()
        showSuccess = true
    }

    private func fetchTodaysDailySet() throws -> DailySet? {
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<DailySet>(
            predicate: #Predicate { $0.date == today }
        )
        return try modelContext.fetch(descriptor).first
    }
}
