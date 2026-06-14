import SwiftUI
import SwiftData

/// WR1 — duplicate word-info card removed; the navigation title carries the
///   word and `navigationSubtitle` (iOS 18+) carries the short definition.
/// WR2 — reasons use the shared `SelectableRow` instead of bespoke
///   `ReasonButton`. Same single-signal selection rules as everywhere else.
struct WordReportSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext

    let word: Word
    let userProgress: UserProgress
    var onSubmitted: () -> Void = {}

    private static let maxNotesLength = 1000

    @State private var selectedReason: WordReportReason?
    @State private var additionalNotes = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var submitError: String?
    @FocusState private var notesFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing.lg) {
                        Text(word.shortDefinition)
                            .font(TypographyTokens.subheadline)
                            .foregroundColor(theme.colors.inkMuted)
                            .multilineTextAlignment(.leading)

                        reasonsSection

                        if selectedReason != nil {
                            notesSection
                        }

                        submitButton
                    }
                    .padding(theme.spacing.lg)
                }
            }
            .navigationTitle(word.word)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.cancel") { dismiss() }
                        .foregroundColor(theme.colors.ink)
                }
            }
            .alert("report.success.title", isPresented: $showSuccess) {
                Button("common.ok") {
                    onSubmitted()
                    dismiss()
                }
            } message: {
                Text("report.success.message")
            }
            .alert("report.submit.error.title", isPresented: Binding(get: { submitError != nil },
                                                                     set: { if !$0 { submitError = nil } })) {
                Button("common.ok") { submitError = nil }
            } message: {
                if let msg = submitError {
                    Text(msg)
                }
            }
        }
    }

    private var reasonsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("report.reason.title")
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.ink)

            VStack(spacing: theme.spacing.sm) {
                ForEach(WordReportReason.allCases, id: \.rawValue) { reason in
                    SelectableRow(
                        title: reason.displayName,
                        isSelected: selectedReason == reason,
                        role: .picker,
                        action: { selectedReason = reason },
                        leading: {
                            Image(systemName: reason.icon)
                                .font(.system(.headline))
                                .foregroundColor(selectedReason == reason ? theme.colors.accent : theme.colors.inkMuted)
                                .frame(width: 28)
                        }
                    )
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text("report.notes.title")
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.ink)

            Text("report.notes.subtitle")
                .font(TypographyTokens.footnote)
                .foregroundColor(theme.colors.inkMuted)

            ThemedTextEditor(
                placeholder: "report.notes.placeholder",
                text: $additionalNotes,
                focus: $notesFocused,
                height: .fixed(100)
            )
            .autocorrectionDisabled()
            .onChange(of: additionalNotes) { _, newValue in
                if newValue.count > Self.maxNotesLength {
                    additionalNotes = String(newValue.prefix(Self.maxNotesLength))
                }
            }

            HStack {
                Spacer()
                Text("\(additionalNotes.count)/\(Self.maxNotesLength)")
                    .font(TypographyTokens.caption)
                    .foregroundColor(additionalNotes.count >= Self.maxNotesLength
                                     ? theme.colors.warn
                                     : theme.colors.inkFaint)
            }
        }
    }

    private var submitButton: some View {
        PrimaryCTAButton("report.submit", isLoading: isSubmitting) {
            submitReport()
        }
        .disabled(selectedReason == nil || isSubmitting)
    }

    private func submitReport() {
        guard let reason = selectedReason else { return }
        isSubmitting = true

        Task {
            do {
                try await services?.report.submitReport(
                    wordId: word.id,
                    wordTerm: word.word,
                    stack: word.stack,
                    reason: reason,
                    additionalNotes: additionalNotes,
                    userLevel: userProgress.level
                )
                isSubmitting = false
                showSuccess = true
            } catch {
                isSubmitting = false
                submitError = error.localizedDescription
            }
        }
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
        tags: ["api"]
    )
}

#Preview("Word Report Sheet — Light") {
    WordReportSheet(
        word: previewWord(),
        userProgress: UserProgress(),
        onSubmitted: {}
    )
    .modelContainer(for: [Word.self, UserProgress.self], inMemory: true)
    .withTheme(ThemeManager())
}

#Preview("Word Report Sheet — Dark") {
    WordReportSheet(
        word: previewWord(),
        userProgress: UserProgress(),
        onSubmitted: {}
    )
    .modelContainer(for: [Word.self, UserProgress.self], inMemory: true)
    .withTheme(ThemeManager())
    .preferredColorScheme(.dark)
}
