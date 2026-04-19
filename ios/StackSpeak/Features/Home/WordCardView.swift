import SwiftUI

struct WordCardView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services

    let word: Word
    let isCompleted: Bool
    let userProgress: UserProgress

    @State private var isExpanded = false
    @State private var showDetail = false
    @State private var showReport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Use onTapGesture on the header instead of a wrapping Button so that
            // NavigationLink and other interactive elements in the expanded section
            // don't steal / suppress taps.
            HStack {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    HStack {
                        Text(word.word)
                            .font(TypographyTokens.cardTitle(density: theme.density))
                            .foregroundColor(theme.colors.ink)

                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.colors.good)
                                .accessibilityLabel(String(localized: "a11y.completed"))
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
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "a11y.wordCard.format",
                defaultValue: "\(word.word). \(isCompleted ? String(localized: "a11y.completed") + "." : "") \(isExpanded ? String(localized: "a11y.tapToCollapse") : String(localized: "a11y.tapToExpand"))"))
            .accessibilityAddTraits(.isButton)

            if isExpanded {
                expandedContent
            }
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showDetail) {
            WordDetailView(word: word, userProgress: userProgress)
        }
        .sheet(isPresented: $showReport) {
            WordReportSheet(word: word, userProgress: userProgress)
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
                    Text("home.wordCard.practice")
                        .font(TypographyTokens.callout.weight(.medium))
                        .foregroundColor(theme.colors.accentText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacing.md)
                        .background(theme.colors.accent)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(format: String(localized: "a11y.practice.format"), word.word))
            }

            HStack(spacing: theme.spacing.md) {
                Button(String(localized: "home.wordCard.open")) { showDetail = true }
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.accent)
                    .accessibilityLabel(String(format: String(localized: "a11y.openDetail.format"), word.word))

                if !userProgress.masteredWordIds.contains(word.id) {
                    Button(String(localized: "home.wordCard.iKnowThis")) { markAsMastered() }
                        .font(TypographyTokens.callout)
                        .foregroundColor(theme.colors.inkMuted)
                        .accessibilityLabel(String(format: String(localized: "a11y.markMastered.format"), word.word))
                }

                Button(String(localized: "home.wordCard.report")) { showReport = true }
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
                    .accessibilityLabel(String(format: String(localized: "a11y.report.format"), word.word))
            }
        }
    }

    private func markAsMastered() {
        services?.progress.markWordMastered(word.id, userProgress: userProgress)
    }
}
