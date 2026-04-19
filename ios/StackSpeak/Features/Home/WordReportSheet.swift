import SwiftUI
import SwiftData

struct WordReportSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services

    let word: Word
    let userProgress: UserProgress

    @Environment(\.modelContext) private var modelContext

    private static let maxNotesLength = 1000

    @State private var selectedReason: WordReportReason?
    @State private var additionalNotes = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false

    var body: some View {
        NavigationView {
            ZStack {
                theme.colors.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing.lg) {
                        wordInfoSection

                        reasonsSection

                        if selectedReason != nil {
                            notesSection
                        }

                        submitButton
                    }
                    .padding(theme.spacing.lg)
                }
            }
            .navigationTitle("report.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.cancel") {
                        dismiss()
                    }
                    .foregroundColor(theme.colors.ink)
                }
            }
            .alert("report.success.title", isPresented: $showSuccess) {
                Button("common.ok") {
                    dismiss()
                }
            } message: {
                Text("report.success.message")
            }
        }
    }

    private var wordInfoSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text("report.wordInfo.title")
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.inkMuted)

            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(word.word)
                    .font(TypographyTokens.title3)
                    .foregroundColor(theme.colors.ink)

                Text(word.shortDefinition)
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)

                Text("L\(word.unlockLevel) · \(word.stack.displayName)")
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkFaint)
            }
            .padding(theme.spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colors.surface)
            .cornerRadius(8)
        }
    }

    private var reasonsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("report.reason.title")
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.ink)

            VStack(spacing: theme.spacing.sm) {
                ForEach(WordReportReason.allCases, id: \.rawValue) { reason in
                    ReasonButton(
                        reason: reason,
                        isSelected: selectedReason == reason,
                        theme: theme
                    ) {
                        selectedReason = reason
                    }
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
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.inkMuted)

            TextEditor(text: $additionalNotes)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
                .frame(height: 100)
                .padding(theme.spacing.sm)
                .background(theme.colors.surface)
                .cornerRadius(8)
                .textContentType(.none)
                .autocorrectionDisabled()
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.colors.line, lineWidth: 1)
                )
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
        Button(action: submitReport) {
            if isSubmitting {
                ProgressView()
                    .tint(theme.colors.accentText)
            } else {
                Text("report.submit")
                    .font(TypographyTokens.headline)
            }
        }
        .foregroundColor(theme.colors.accentText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.lg)
        .background(selectedReason == nil ? theme.colors.inkFaint : theme.colors.accent)
        .cornerRadius(12)
        .disabled(selectedReason == nil || isSubmitting)
    }

    private func submitReport() {
        guard let reason = selectedReason else { return }

        isSubmitting = true

        do {
            try services?.report.submitReport(
                wordId: word.id,
                wordTerm: word.word,
                stack: word.stack.rawValue,
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

struct ReasonButton: View {
    let reason: WordReportReason
    let isSelected: Bool
    let theme: ThemeManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: reason.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? theme.colors.accent : theme.colors.ink)
                    .frame(width: 32, height: 32)
                    .background(isSelected ? theme.colors.accentBg : theme.colors.bg)
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(reason.displayName)
                        .font(TypographyTokens.callout.weight(.medium))
                        .foregroundColor(theme.colors.ink)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.colors.accent)
                }
            }
            .padding(theme.spacing.md)
            .background(theme.colors.surface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.colors.accent : theme.colors.line, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
