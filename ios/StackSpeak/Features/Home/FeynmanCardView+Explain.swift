import SwiftUI

// MARK: - Explain stage (TextEditor + mic + Submit)

extension FeynmanCardView {
    var explainStage: some View {
        // ScrollView so the user can scroll to reach Submit when the
        // keyboard is up; `.scrollDismissesKeyboard(.interactively)` lets
        // them swipe the keyboard away with a downward drag.
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                stageLabel("feynman.stage.explain")

                Text("feynman.explain.about")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
                    .lineSpacing(7)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, theme.spacing.xs)

                Text("feynman.explain.prompt")
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.ink)

                explanationEditor

                if let micError {
                    Text(micError)
                        .font(TypographyTokens.caption)
                        .foregroundColor(theme.colors.warn)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    var explanationEditor: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack {
                Text("feynman.explain.inputLabel")
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkFaint)
                Spacer()
                if let speech = speechService,
                   speech.authorizationStatus != .denied,
                   speech.authorizationStatus != .restricted {
                    micButton(speech: speech)
                }
            }

            // FC1 — TextEditor placeholder via ZStack overlay (TextEditor doesn't
            // support placeholders natively).
            ZStack(alignment: .topLeading) {
                if explanation.isEmpty {
                    Text("feynman.explain.placeholder")
                        .font(TypographyTokens.body)
                        .foregroundColor(theme.colors.inkFaint)
                        .padding(.horizontal, theme.spacing.sm + 5)
                        .padding(.vertical, theme.spacing.sm + 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $explanation)
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(theme.spacing.sm)
                    .background(theme.colors.surfaceAlt)
                    .clipShape(.rect(cornerRadius: RadiusTokens.inline))
                    .focused($explanationFocused)
                    .accessibilityLabel(String(localized: "a11y.feynman.explanationInput"))
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(String(localized: "common.done")) {
                                explanationFocused = false
                            }
                            .foregroundColor(theme.colors.accent)
                        }
                    }
                    .onChange(of: explanation) { _, newValue in
                        if newValue.count > Self.maxExplanationLength {
                            explanation = String(newValue.prefix(Self.maxExplanationLength))
                        }
                    }
                    .onChange(of: speechService?.transcript ?? "") { _, newValue in
                        if !newValue.isEmpty {
                            explanation = String(newValue.prefix(Self.maxExplanationLength))
                            inputMethod = .voice
                        }
                    }
            }

            HStack {
                if speechService?.authorizationStatus == .denied {
                    Text("feynman.explain.micDenied")
                        .font(TypographyTokens.caption)
                        .foregroundColor(theme.colors.inkMuted)
                }
                Spacer()
                Text("\(explanation.count)/\(Self.maxExplanationLength)")
                    .font(TypographyTokens.caption)
                    .foregroundColor(explanation.count >= Self.maxExplanationLength
                                     ? theme.colors.warn
                                     : theme.colors.inkFaint)
            }
        }
    }

    /// FC2 — clearly distinct idle vs. recording state.
    func micButton(speech: any SpeechRepository) -> some View {
        let isRecording = speech.isRecording
        return Button(action: toggleRecording) {
            ZStack {
                Circle()
                    .fill(isRecording ? theme.colors.bad : theme.colors.surfaceAlt)
                    .frame(width: 36, height: 36)
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .font(.system(.callout, weight: .semibold))
                    .foregroundColor(isRecording ? .white : theme.colors.inkMuted)
                    .symbolEffect(.pulse, isActive: isRecording)
            }
        }
        .accessibilityLabel(isRecording
                            ? String(localized: "a11y.feynman.stopRecording")
                            : String(localized: "a11y.feynman.startRecording"))
    }

    @ViewBuilder
    var explainControls: some View {
        let trimmed = explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(spacing: theme.spacing.xs) {
            HStack(spacing: theme.spacing.md) {
                if isComingSoon {
                    Button(action: submitAsComingSoon) {
                        Text("feynman.explain.markPracticed")
                            .font(TypographyTokens.callout.weight(.medium))
                            .foregroundColor(theme.colors.inkMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacing.md)
                            .background(theme.colors.surfaceAlt)
                            .clipShape(.rect(cornerRadius: RadiusTokens.card))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "a11y.feynman.markPracticed"))
                }

                PrimaryCTAButton("feynman.explain.submit") {
                    submitExplanation(trimmed: trimmed)
                }
                .disabled(trimmed.isEmpty)
            }
            if trimmed.isEmpty {
                Text("feynman.explain.submitHint")
                    .font(TypographyTokens.footnote)
                    .foregroundColor(theme.colors.inkMuted)
            }
        }
    }
}
