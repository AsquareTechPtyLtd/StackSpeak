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
                        role: .multiselect,
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

            ZStack(alignment: .topLeading) {
                if additionalNotes.isEmpty {
                    Text("report.notes.placeholder")
                        .font(TypographyTokens.body)
                        .foregroundColor(theme.colors.inkFaint)
                        .padding(.horizontal, theme.spacing.sm + 5)
                        .padding(.vertical, theme.spacing.sm + 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $additionalNotes)
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.ink)
                    .scrollContentBackground(.hidden)
                    .frame(height: 100)
                    .padding(theme.spacing.sm)
                    .background(theme.colors.surfaceAlt)
                    .clipShape(.rect(cornerRadius: RadiusTokens.inline))
                    .textContentType(.none)
                    .autocorrectionDisabled()
                    .onChange(of: additionalNotes) { _, newValue in
                        if newValue.count > Self.maxNotesLength {
                            additionalNotes = String(newValue.prefix(Self.maxNotesLength))
                        }
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
            }
        }
    }
}
