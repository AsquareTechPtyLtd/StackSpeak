import SwiftUI

enum FeynmanStage: Int, CaseIterable {
    case word
    case simple
    case technical
    case explain
    case connector
    case done
}

/// One daily word, presented as a guided Feynman-technique flow:
/// word → plain-English definition → everyday analogy → user explains in their
/// own words → technical depth → done. Coming-soon words collapse the simple
/// and connector stages into a single fallback stage.
struct FeynmanCardView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services

    let word: Word
    let userProgress: UserProgress
    let isCompleted: Bool
    let latestExplanation: PracticedSentence?
    let onSubmit: (String, InputMethod, Bool) -> Void  // Added Bool for markAsMastered

    @State private var stage: FeynmanStage
    @State private var explanation: String = ""
    @State private var inputMethod: InputMethod = .typed
    @State private var micError: String?
    @State private var showReport = false
    @State private var showDetail = false
    @State private var flipRotation: Double = 0

    private static let maxExplanationLength = 500

    init(
        word: Word,
        userProgress: UserProgress,
        isCompleted: Bool,
        latestExplanation: PracticedSentence?,
        onSubmit: @escaping (String, InputMethod, Bool) -> Void
    ) {
        self.word = word
        self.userProgress = userProgress
        self.isCompleted = isCompleted
        self.latestExplanation = latestExplanation
        self.onSubmit = onSubmit
        _stage = State(initialValue: isCompleted ? .done : .word)
    }

    private var isComingSoon: Bool {
        word.simpleDefinition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || word.connector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var speechService: (any SpeechRepository)? {
        services?.speech
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            headerRow
            stageContent
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
            Spacer(minLength: 0)
            advanceControls
        }
        .padding(theme.spacing.cardPadding(density: theme.density))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.colors.surface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .rotation3DEffect(
            .degrees(flipRotation),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .sheet(isPresented: $showReport) {
            WordReportSheet(word: word, userProgress: userProgress)
        }
        .sheet(isPresented: $showDetail) {
            WordDetailView(word: word, userProgress: userProgress)
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(word.word)
                    .font(TypographyTokens.cardTitle(density: theme.density))
                    .foregroundColor(theme.colors.ink)
                    .accessibilityAddTraits(.isHeader)

                Text(word.pronunciation)
                    .font(TypographyTokens.mono)
                    .foregroundColor(theme.colors.inkMuted)
                    .accessibilityLabel(String(format: String(localized: "a11y.pronunciation.format"), word.pronunciation))

                Text("L\(word.unlockLevel) · \(LevelDefinition.definition(for: word.unlockLevel)?.title ?? "")")
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkFaint)
            }

            Spacer()

            stageIndicator
        }
    }

    private var stageIndicator: some View {
        Text(String(format: String(localized: "feynman.stage.counter.format"),
                    visibleStageIndex, visibleStageTotal))
            .font(TypographyTokens.caption)
            .foregroundColor(theme.colors.inkFaint)
            .padding(.horizontal, theme.spacing.sm)
            .padding(.vertical, theme.spacing.xs)
            .background(theme.colors.accentBg)
            .cornerRadius(4)
    }

    /// Stages visible for this word. Coming-soon words skip the connector stage
    /// (nothing meaningful to show), so the counter reads 5 total instead of 6.
    private var visibleStageTotal: Int { isComingSoon ? 5 : 6 }

    private var visibleStageIndex: Int {
        switch stage {
        case .word:      return 1
        case .simple:    return 2
        case .technical: return 3
        case .explain:   return 4
        case .connector: return 5
        case .done:      return isComingSoon ? 5 : 6
        }
    }

    // MARK: - Stage content

    @ViewBuilder
    private var stageContent: some View {
        switch stage {
        case .word:
            wordStage
        case .simple:
            simpleStage
        case .connector:
            connectorStage
        case .explain:
            explainStage
        case .technical:
            technicalStage
        case .done:
            doneStage
        }
    }

    private var wordStage: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            stageLabel("feynman.stage.word")
            Text("feynman.word.prompt")
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)

            Spacer()

            // Report button on first screen
            Button(action: reportAndSkip) {
                HStack(spacing: 4) {
                    Image(systemName: "flag")
                        .font(.system(size: 12))
                    Text("Report issue & skip")
                        .font(TypographyTokens.caption)
                }
                .foregroundColor(theme.colors.warn)
                .padding(.horizontal, theme.spacing.sm)
                .padding(.vertical, 6)
                .background(theme.colors.warn.opacity(0.1))
                .cornerRadius(20)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Report an issue with this word and skip it")
        }
    }

    private var simpleStage: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            stageLabel("feynman.stage.simple")
            if isComingSoon {
                comingSoonBody
            } else {
                Text(word.simpleDefinition)
                    .font(TypographyTokens.title3)
                    .foregroundColor(theme.colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var connectorStage: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            stageLabel("feynman.stage.connector")
            Text("feynman.connector.intro")
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
            Text(word.connector)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
                .italic()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var comingSoonBody: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("feynman.comingSoon.title")
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.ink)
            Text("feynman.comingSoon.message")
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Divider().background(theme.colors.line)

            Text(word.shortDefinition)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var explainStage: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            stageLabel("feynman.stage.explain")
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

    private var explanationEditor: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack {
                Text("feynman.explain.inputLabel")
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkFaint)

                Spacer()

                if let speech = speechService, speech.authorizationStatus != .denied && speech.authorizationStatus != .restricted {
                    Button(action: toggleRecording) {
                        Image(systemName: (speech.isRecording) ? "mic.fill" : "mic")
                            .font(.system(size: 18))
                            .foregroundColor((speech.isRecording) ? theme.colors.accent : theme.colors.inkMuted)
                            .padding(theme.spacing.sm)
                            .background(theme.colors.accentBg)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(speech.isRecording
                                        ? String(localized: "a11y.feynman.stopRecording")
                                        : String(localized: "a11y.feynman.startRecording"))
                }
            }

            TextEditor(text: $explanation)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
                .frame(minHeight: 120)
                .padding(theme.spacing.sm)
                .background(theme.colors.surfaceAlt)
                .cornerRadius(8)
                .accessibilityLabel(String(localized: "a11y.feynman.explanationInput"))
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

    private var technicalStage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                stageLabel("feynman.stage.technical")

                section(title: "wordDetail.section.definition") {
                    Text(word.longDefinition)
                        .font(TypographyTokens.body)
                        .foregroundColor(theme.colors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !word.techContext.isEmpty {
                    section(title: "wordDetail.section.techContext") {
                        Text(word.techContext)
                            .font(TypographyTokens.callout)
                            .foregroundColor(theme.colors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !word.exampleSentence.isEmpty {
                    section(title: "wordDetail.section.example") {
                        Text(word.exampleSentence)
                            .font(TypographyTokens.body)
                            .foregroundColor(theme.colors.ink)
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
                        .cornerRadius(8)
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

    private var doneStage: some View {
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
                        .font(TypographyTokens.caption)
                        .foregroundColor(theme.colors.inkFaint)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(latestExplanation.sentence)
                        .font(TypographyTokens.body)
                        .foregroundColor(theme.colors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(theme.spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.colors.surfaceAlt)
                        .cornerRadius(8)
                }
            }

            if !word.connector.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacing.sm) {
                    Text("feynman.done.takeaway")
                        .font(TypographyTokens.caption)
                        .foregroundColor(theme.colors.inkFaint)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(word.connector)
                        .font(TypographyTokens.body)
                        .foregroundColor(theme.colors.ink)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: theme.spacing.md) {
                Button(action: { showDetail = true }) {
                    Text("feynman.done.openDetail")
                        .font(TypographyTokens.callout)
                        .foregroundColor(theme.colors.accent)
                }
                .accessibilityLabel(String(format: String(localized: "a11y.openDetail.format"), word.word))

                Spacer()

                Button(action: { showReport = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "flag")
                            .font(.system(size: 12))
                        Text("home.wordCard.report")
                            .font(TypographyTokens.caption)
                    }
                    .foregroundColor(theme.colors.warn)
                    .padding(.horizontal, theme.spacing.sm)
                    .padding(.vertical, 6)
                    .background(theme.colors.warn.opacity(0.1))
                    .cornerRadius(20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(format: String(localized: "a11y.report.format"), word.word))
            }
        }
    }

    // MARK: - Stage controls

    @ViewBuilder
    private var advanceControls: some View {
        switch stage {
        case .word:
            VStack(spacing: theme.spacing.sm) {
                primaryButton(titleKey: "feynman.advance.next", enabled: true) {
                    advance()
                }

                Button(action: skipWord) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                        Text("Skip & mark finished")
                            .font(TypographyTokens.callout)
                    }
                    .foregroundColor(theme.colors.good)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacing.sm)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip this word and mark as finished")
            }
        case .simple:
            primaryButton(titleKey: "feynman.advance.next", enabled: true) {
                advance()
            }
        case .technical:
            primaryButton(titleKey: "feynman.advance.readyToExplain", enabled: true) {
                advance()
            }
        case .explain:
            explainControls
        case .connector:
            primaryButton(titleKey: "feynman.advance.finish", enabled: true) {
                advance()
            }
        case .done:
            EmptyView()
        }
    }

    @ViewBuilder
    private var explainControls: some View {
        let trimmed = explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        HStack(spacing: theme.spacing.md) {
            if isComingSoon {
                Button(action: submitAsComingSoon) {
                    Text("feynman.explain.markPracticed")
                        .font(TypographyTokens.callout.weight(.medium))
                        .foregroundColor(theme.colors.inkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacing.md)
                        .background(theme.colors.surfaceAlt)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "a11y.feynman.markPracticed"))
            }

            primaryButton(titleKey: "feynman.explain.submit", enabled: !trimmed.isEmpty) {
                submitExplanation(trimmed: trimmed)
            }
        }
    }

    private func primaryButton(titleKey: LocalizedStringKey, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(titleKey)
                .font(TypographyTokens.headline)
                .foregroundColor(theme.colors.accentText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.md)
                .background(enabled ? theme.colors.accent : theme.colors.inkFaint)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Actions

    private func advance() {
        guard let next = nextStage(from: stage) else { return }

        // Flip animation: rotate halfway, change content, then complete rotation
        withAnimation(.easeIn(duration: 0.15)) {
            flipRotation = 90
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            stage = next

            withAnimation(.easeOut(duration: 0.15)) {
                flipRotation = 0
            }
        }
    }

    /// Picks the next stage. Order is word → simple → technical → explain → connector → done.
    /// Coming-soon words skip the connector stage (no content to show), so explain leads
    /// straight to done for those.
    private func nextStage(from current: FeynmanStage) -> FeynmanStage? {
        switch current {
        case .word:
            return .simple
        case .simple:
            return .technical
        case .technical:
            return .explain
        case .explain:
            return isComingSoon ? .done : .connector
        case .connector:
            return .done
        case .done:
            return nil
        }
    }

    private func submitExplanation(trimmed: String) {
        stopRecordingIfNeeded()
        onSubmit(trimmed, inputMethod, false)  // Normal submission, not auto-mastered

        // Flip animation for submit
        withAnimation(.easeIn(duration: 0.15)) {
            flipRotation = 90
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            stage = isComingSoon ? .done : .connector

            withAnimation(.easeOut(duration: 0.15)) {
                flipRotation = 0
            }
        }
    }

    private func submitAsComingSoon() {
        stopRecordingIfNeeded()
        // Empty explanation — ProgressService skips the PracticedSentence row but
        // still inserts the word into wordsPracticedIds + creates a ReviewState.
        onSubmit("", .typed, false)  // Normal practice, not mastered

        // Flip animation for submit
        withAnimation(.easeIn(duration: 0.15)) {
            flipRotation = 90
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            stage = .done

            withAnimation(.easeOut(duration: 0.15)) {
                flipRotation = 0
            }
        }
    }

    private func skipWord() {
        stopRecordingIfNeeded()
        // Mark as MASTERED - counts toward level progression, won't appear in assessments
        onSubmit("", .typed, true)  // true = mark as mastered

        // Flip animation for skip
        withAnimation(.easeIn(duration: 0.15)) {
            flipRotation = 90
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            stage = .done

            withAnimation(.easeOut(duration: 0.15)) {
                flipRotation = 0
            }
        }
    }

    private func reportAndSkip() {
        // Show report sheet first
        showReport = true

        // Mark as MASTERED - counts toward level progression, won't appear in assessments
        stopRecordingIfNeeded()
        onSubmit("", .typed, true)  // true = mark as mastered

        // Flip animation to done stage
        withAnimation(.easeIn(duration: 0.15)) {
            flipRotation = 90
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            stage = .done

            withAnimation(.easeOut(duration: 0.15)) {
                flipRotation = 0
            }
        }
    }

    private func toggleRecording() {
        guard let speech = speechService else { return }
        if speech.isRecording {
            speech.stopRecording()
            return
        }
        Task { @MainActor in
            if speech.authorizationStatus == .notDetermined {
                _ = await speech.requestAuthorization()
            }
            guard speech.authorizationStatus == .authorized else {
                micError = String(localized: "feynman.explain.micDenied")
                return
            }
            do {
                try speech.startRecording()
                micError = nil
            } catch {
                micError = error.localizedDescription
            }
        }
    }

    private func stopRecordingIfNeeded() {
        if speechService?.isRecording == true {
            speechService?.stopRecording()
        }
    }

    // MARK: - Helpers

    private func stageLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(TypographyTokens.caption)
            .foregroundColor(theme.colors.inkFaint)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    @ViewBuilder
    private func section<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            SectionHeader(title: title)
            content()
        }
    }
}
