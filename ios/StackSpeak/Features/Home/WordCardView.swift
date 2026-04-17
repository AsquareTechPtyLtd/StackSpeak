import SwiftUI

struct WordCardView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext

    let word: Word
    let isCompleted: Bool
    let userProgress: UserProgress

    @State private var isExpanded = false
    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() } }) {
                HStack {
                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        HStack {
                            Text(word.word)
                                .font(TypographyTokens.cardTitle(density: theme.density))
                                .foregroundColor(theme.colors.ink)

                            if isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(theme.colors.good)
                            }
                        }

                        Text(word.pronunciation)
                            .font(TypographyTokens.mono)
                            .foregroundColor(theme.colors.inkMuted)

                        Text("L\(word.unlockLevel) · \(LevelDefinition.definition(for: word.unlockLevel)?.title ?? "")")
                            .font(TypographyTokens.caption)
                            .foregroundColor(theme.colors.inkFaint)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(theme.colors.inkMuted)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent
            }
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
        .shadow(color: theme.colors.line, radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showDetail) {
            WordDetailView(word: word, userProgress: userProgress)
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Divider()
                .background(theme.colors.line)
                .padding(.vertical, theme.spacing.sm)

            Text(word.shortDefinition)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)

            if !isCompleted {
                NavigationLink(destination: SentencePracticeView(word: word, userProgress: userProgress)) {
                    Text("Practice")
                        .font(TypographyTokens.callout.weight(.medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacing.md)
                        .background(theme.colors.accent)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: theme.spacing.md) {
                Button(action: { showDetail = true }) {
                    Text("Open")
                        .font(TypographyTokens.callout)
                        .foregroundColor(theme.colors.accent)
                }

                if !userProgress.masteredWordIds.contains(word.id) {
                    Button(action: { markAsMastered() }) {
                        Text("I know this")
                            .font(TypographyTokens.callout)
                            .foregroundColor(theme.colors.inkMuted)
                    }
                }
            }
        }
    }

    private func markAsMastered() {
        let progressService = ProgressService(modelContext: modelContext)
        progressService.markWordMastered(word.id, userProgress: userProgress)
        try? modelContext.save()
    }
}
