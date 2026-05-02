import SwiftUI

// MARK: - Stage views (excluding explain — see FeynmanCardView+Explain.swift)

extension FeynmanCardView {
    @ViewBuilder
    var stageContent: some View {
        switch stage {
        case .simple:    simpleStage
        case .connector: connectorStage
        case .explain:   explainStage
        case .technical: technicalStage
        case .done:      doneStage
        }
    }

    var simpleStage: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            stageLabel("feynman.stage.simple")
            if isComingSoon {
                comingSoonBody
            } else {
                Text(word.simpleDefinition)
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.ink)
                    .lineSpacing(8)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var connectorStage: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            stageLabel("feynman.stage.connector")
            Text("feynman.connector.intro")
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
                .lineSpacing(7)
                .multilineTextAlignment(.leading)
            Text(word.connector)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
                .lineSpacing(8)
                .multilineTextAlignment(.leading)
                .italic()
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, theme.spacing.lg)
        }
    }

    var comingSoonBody: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("feynman.comingSoon.title")
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.ink)
            Text("feynman.comingSoon.message")
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
                .lineSpacing(7)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Divider().background(theme.colors.line)
            Text(word.shortDefinition)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
                .lineSpacing(8)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var technicalStage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                stageLabel("feynman.stage.technical")

                section(title: "wordDetail.section.definition") {
                    Text(word.longDefinition)
                        .font(TypographyTokens.body)
                        .foregroundColor(theme.colors.ink)
                        .lineSpacing(8)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !word.techContext.isEmpty {
                    section(title: "wordDetail.section.techContext") {
                        Text(word.techContext)
                            .font(TypographyTokens.callout)
                            .foregroundColor(theme.colors.ink)
                            .lineSpacing(7)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !word.exampleSentence.isEmpty {
                    section(title: "wordDetail.section.example") {
                        Text(word.exampleSentence)
                            .font(TypographyTokens.body)
                            .foregroundColor(theme.colors.ink)
                            .lineSpacing(8)
                            .multilineTextAlignment(.leading)
                            .italic()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !word.codeExampleCode.isEmpty {
                    section(title: "wordDetail.section.code") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(word.codeExampleCode)
                                .font(TypographyTokens.code)
                                .foregroundColor(theme.colors.codeInk)
                                .padding(theme.spacing.md)
                        }
                        .background(theme.colors.codeBg)
                        .clipShape(.rect(cornerRadius: RadiusTokens.inline))
                        .accessibilityLabel(String(format: String(localized: "a11y.codeExample.format"), word.codeExampleLanguage))
                    }
                }

                if !word.etymology.isEmpty {
                    section(title: "wordDetail.section.etymology") {
                        Text(word.etymology)
                            .font(TypographyTokens.etymology)
                            .foregroundColor(theme.colors.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    var doneStage: some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            HStack(spacing: theme.spacing.sm) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(theme.colors.good)
                Text("feynman.done.title")
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.ink)
            }

            if let latestExplanation, !latestExplanation.sentence.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacing.sm) {
                    Text("feynman.done.yourExplanation")
                        .font(TypographyTokens.subheadline.weight(.medium))
                        .foregroundColor(theme.colors.inkMuted)
                    Text(latestExplanation.sentence)
                        .font(TypographyTokens.body)
                        .foregroundColor(theme.colors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(theme.spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.colors.surfaceAlt)
                        .clipShape(.rect(cornerRadius: RadiusTokens.inline))
                }
            }

            if !word.connector.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacing.sm) {
                    Text("feynman.done.takeaway")
                        .font(TypographyTokens.subheadline.weight(.medium))
                        .foregroundColor(theme.colors.inkMuted)
                    Text(word.connector)
                        .font(TypographyTokens.body)
                        .foregroundColor(theme.colors.ink)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, theme.spacing.md)
                }
            }

            Button(action: { showDetail = true }) {
                Text("feynman.done.openDetail")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.accent)
            }
            .accessibilityLabel(String(format: String(localized: "a11y.openDetail.format"), word.word))
        }
    }

    // MARK: - Helpers

    /// F4 — sentence-case stage labels. Reduced from the previous tracked
    /// uppercase caption to a small medium-weight label.
    func stageLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(TypographyTokens.subheadline.weight(.medium))
            .foregroundColor(theme.colors.inkMuted)
    }

    @ViewBuilder
    func section<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            SectionHeader(title: title)
            content()
        }
    }
}
