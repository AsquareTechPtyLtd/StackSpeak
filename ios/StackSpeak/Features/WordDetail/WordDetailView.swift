import SwiftUI

/// Typography-led reader for a single word.
///
/// Presented as a sheet from the Feynman card's Done stage and as a pushed
/// screen from caller. No inner NavigationStack — the caller wraps in one
/// if needed.
///
/// WD1 — replaces the previous five-stacked-cards layout with a single
/// scrollable reading column. Sections separate by whitespace and a small
/// hairline-tracked label, not by surface fills.
struct WordDetailView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    let word: Word
    let userProgress: UserProgress

    var isBookmarked: Bool { userProgress.bookmarkedWordIds.contains(word.id) }
    var isMastered: Bool   { userProgress.masteredWordIds.contains(word.id) }

    var body: some View {
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.xxl) {
                    headerBlock
                    shortDefinition
                    longDefinitionBlock
                    if !word.techContext.isEmpty { techContextBlock }
                    if !word.exampleSentence.isEmpty { exampleBlock }
                    if !word.codeExampleCode.isEmpty { codeBlock }
                    if !word.etymology.isEmpty { etymologyBlock }
                    Spacer(minLength: theme.spacing.xxxl)
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.horizontal, theme.spacing.xl)
                .padding(.top, theme.spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle(word.word)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarMenu }
    }

    // MARK: - Toolbar (WD2 — single menu replaces twin icon buttons)

    @ToolbarContentBuilder
    private var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(action: toggleBookmark) {
                    Label(isBookmarked
                          ? String(localized: "wordDetail.menu.removeBookmark")
                          : String(localized: "wordDetail.menu.bookmark"),
                          systemImage: isBookmarked ? "bookmark.fill" : "bookmark")
                }
                Button(action: toggleMastered) {
                    Label(isMastered
                          ? String(localized: "wordDetail.menu.unmaster")
                          : String(localized: "wordDetail.menu.master"),
                          systemImage: isMastered ? "checkmark.circle.fill" : "checkmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(theme.colors.accent)
            }
            .accessibilityLabel(String(localized: "wordDetail.menu.label"))
        }
    }

    // MARK: - Sections

    private var headerBlock: some View {
        HStack(spacing: theme.spacing.sm) {
            Text(word.pronunciation)
                .font(TypographyTokens.mono)
                .foregroundColor(theme.colors.inkMuted)
                .accessibilityLabel(String(format: String(localized: "a11y.pronunciation.format"), word.pronunciation))
            if isMastered {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(theme.colors.good)
                    .accessibilityLabel(String(localized: "a11y.mastered"))
            }
            if isBookmarked {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(theme.colors.accent)
                    .accessibilityLabel(String(localized: "a11y.bookmarked"))
            }
            Spacer()
            MetaCaption(level: word.unlockLevel,
                        secondary: word.partOfSpeech)
        }
    }

    private var shortDefinition: some View {
        Text(word.shortDefinition)
            .font(TypographyTokens.title2)
            .foregroundColor(theme.colors.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var longDefinitionBlock: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            SectionHeader(title: "wordDetail.section.definition")
            Text(word.longDefinition)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var techContextBlock: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            SectionHeader(title: "wordDetail.section.techContext")
            HStack(alignment: .top, spacing: theme.spacing.md) {
                Rectangle()
                    .fill(theme.colors.accent.opacity(0.5))
                    .frame(width: 2)
                Text(word.techContext)
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var exampleBlock: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            SectionHeader(title: "wordDetail.section.example")
            Text("\u{201C}\(word.exampleSentence)\u{201D}")
                .font(TypographyTokens.etymologyLarge)
                .foregroundColor(theme.colors.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, theme.spacing.xs)
        }
    }

    private var codeBlock: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            SectionHeader(title: "wordDetail.section.code")
            ScrollView(.horizontal, showsIndicators: false) {
                Text(word.codeExampleCode)
                    .font(TypographyTokens.code)
                    .foregroundColor(theme.colors.codeInk)
                    .padding(theme.spacing.md)
            }
            .background(theme.colors.codeBg)
            .clipShape(.rect(cornerRadius: RadiusTokens.inline))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.inline)
                    .stroke(theme.colors.line, lineWidth: 0.5)
            )
            .accessibilityLabel(String(format: String(localized: "a11y.codeExample.format"), word.codeExampleLanguage))
        }
    }

    private var etymologyBlock: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            SectionHeader(title: "wordDetail.section.etymology")
            Text(word.etymology)
                .font(TypographyTokens.etymology)
                .foregroundColor(theme.colors.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

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

/// Sentence-case section label (F4). Replaces the previous UPPERCASE-tracked
/// caption — that styling is now reserved for code/metadata, not UI chrome.
struct SectionHeader: View {
    @Environment(\.theme) private var theme
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(TypographyTokens.subheadline.weight(.medium))
            .foregroundColor(theme.colors.inkMuted)
    }
}
