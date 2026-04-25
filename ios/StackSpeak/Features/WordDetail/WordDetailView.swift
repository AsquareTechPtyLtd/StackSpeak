import SwiftUI

/// Presented as a sheet from the Feynman card's Done stage and as a pushed screen from LibraryView.
/// No inner NavigationStack — the caller is responsible for wrapping in one if needed.
struct WordDetailView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services

    let word: Word
    let userProgress: UserProgress

    var isBookmarked: Bool {
        userProgress.bookmarkedWordIds.contains(word.id)
    }

    var isMastered: Bool {
        userProgress.masteredWordIds.contains(word.id)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing.xl) {
                        headerSection
                        definitionsSection
                        contextSection
                        exampleSentenceSection
                        if !word.codeExampleCode.isEmpty {
                            codeExampleSection
                        }
                        etymologySection
                    }
                    .frame(maxWidth: 720)
                    .padding(theme.spacing.lg)
                }
            }
            .navigationTitle(word.word)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: theme.spacing.md) {
                        Button(action: toggleBookmark) {
                            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                .foregroundColor(theme.colors.accent)
                        }
                        .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark \(word.word)")

                        Button(action: toggleMastered) {
                            Image(systemName: isMastered ? "checkmark.circle.fill" : "checkmark.circle")
                                .foregroundColor(isMastered ? theme.colors.good : theme.colors.inkMuted)
                        }
                        .accessibilityLabel(isMastered ? "Unmark as mastered" : "Mark \(word.word) as mastered")
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text(word.pronunciation)
                .font(TypographyTokens.mono)
                .foregroundColor(theme.colors.inkMuted)

            Text(word.partOfSpeech)
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.inkFaint)
                .padding(.horizontal, theme.spacing.sm)
                .padding(.vertical, theme.spacing.xs)
                .background(theme.colors.accentBg)
                .cornerRadius(4)

            Text("L\(word.unlockLevel) · \(LevelDefinition.definition(for: word.unlockLevel)?.title ?? "")")
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.inkFaint)
        }
    }

    private var definitionsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            SectionHeader(title: "wordDetail.section.definition")
            Text(word.shortDefinition)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
            Text(word.longDefinition)
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            SectionHeader(title: "wordDetail.section.techContext")
            Text(word.techContext)
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.ink)
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private var exampleSentenceSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            SectionHeader(title: "wordDetail.section.example")
            Text(word.exampleSentence)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
                .italic()
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private var codeExampleSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            SectionHeader(title: "wordDetail.section.code")
            ScrollView(.horizontal, showsIndicators: false) {
                Text(word.codeExampleCode)
                    .font(TypographyTokens.code)
                    .foregroundColor(theme.colors.codeInk)
                    .padding(theme.spacing.md)
            }
            .background(theme.colors.codeBg)
            .cornerRadius(8)
            .accessibilityLabel("Code example in \(word.codeExampleLanguage)")
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private var etymologySection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            SectionHeader(title: "wordDetail.section.etymology")
            Text(word.etymology)
                .font(TypographyTokens.etymology)
                .foregroundColor(theme.colors.inkMuted)
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .background(theme.colors.surface)
        .cornerRadius(12)
    }

    private func toggleBookmark() {
        services?.progress.toggleBookmark(word.id, userProgress: userProgress)
    }

    private func toggleMastered() {
        if isMastered {
            services?.progress.unmarkWordMastered(word.id, userProgress: userProgress)
        } else {
            services?.progress.markWordMastered(word.id, userProgress: userProgress)
        }
    }
}

struct SectionHeader: View {
    @Environment(\.theme) private var theme
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(TypographyTokens.caption)
            .foregroundColor(theme.colors.inkFaint)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}
