import SwiftUI

// MARK: - Explain stage (TextEditor + mic + Submit)

extension FeynmanCardView {
    /// Scroll target so the editor can be pulled fully into view when focused.
    static let explainEditorID = "feynman.explanationEditor"

    var explainStage: some View {
        // ScrollView so the user can scroll to reach Submit when the
        // keyboard is up; `.scrollDismissesKeyboard(.interactively)` lets
        // them swipe the keyboard away with a downward drag.
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    // Collapse the guidance while typing so the whole input box
                    // fits in the space above the keyboard.
                    if !explanationFocused {
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
                    }

                    explanationEditor
                        .id(Self.explainEditorID)

                    if let micError {
                        Text(micError)
                            .font(TypographyTokens.caption)
                            .foregroundColor(theme.colors.warn)
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2),
                           value: explanationFocused)
            }
            .scrollDismissesKeyboard(.interactively)
            // When the keyboard comes up, pull the editor to the top of the
            // scroll area so the entire box is visible above the keyboard.
            .onChange(of: explanationFocused) { _, focused in
                guard focused else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    proxy.scrollTo(Self.explainEditorID, anchor: .top)
                }
            }
        }
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

            ThemedTextEditor(
                placeholder: "feynman.explain.placeholder",
                text: $explanation,
                focus: $explanationFocused,
                height: .grows(min: 120),
                accessibilityLabel: String(localized: "a11y.feynman.explanationInput")
            )
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
                    .foregroundColor(isRecording ? theme.colors.badInk : theme.colors.inkMuted)
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
            // Suppressed while recording — "type a few words" would contradict
            // the active voice input filling the editor.
            if trimmed.isEmpty && speechService?.isRecording != true {
                Text("feynman.explain.submitHint")
                    .font(TypographyTokens.footnote)
                    .foregroundColor(theme.colors.inkMuted)
            }
        }
    }
}
