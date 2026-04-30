import SwiftUI

/// Stages of the Feynman flow for one word.
///
/// The standalone `word` stage ("say it out loud") was removed once Today
/// became a list — the user already sees + says the word from the list before
/// drilling in. Flow is now: simple → technical → explain → connector → done.
enum FeynmanStage: Int, CaseIterable {
    case simple
    case technical
    case explain
    case connector
    case done
}

/// One daily word, presented as a guided Feynman-technique flow.
///
/// T1/T3 — header collapsed to word + pronunciation only (level meta moved to
///   a card-level status line in HomeView).
/// T3 — stage counter replaced with a thin progress bar at the top of the
///   card body. The chip-style indicator was the loudest thing on the screen;
///   a 2pt capsule says the same thing in 1% of the visual weight.
/// T4 — Skip / Report-and-skip moved into a `Menu` (⋯). Only one primary
///   action competes for attention now.
/// F2 — surface shadow replaced with a 0.5pt hairline border.
/// F8 — 3-D rotation flip replaced with cross-fade for stage transitions.
/// F6/F7 — selection haptic + symbol effect on advance and submit.
struct FeynmanCardView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let word: Word
    let userProgress: UserProgress
    let isCompleted: Bool
    let latestExplanation: PracticedSentence?
    let onSubmit: (String, InputMethod, Bool) -> Void  // explanation, inputMethod, markAsMastered
    /// Optional — fires whenever the card reaches the `done` stage (either
    /// via submit, skip, or report). Used by `WordFeynmanScreen` to surface
    /// a post-completion CTA. Default is no-op so other call sites stay simple.
    let onStageDidReachDone: () -> Void

    @State private var stage: FeynmanStage
    @State private var explanation: String = ""
    @State private var inputMethod: InputMethod = .typed
    @State private var micError: String?
    @State private var showReport = false
    @State private var showDetail = false
    @State private var advanceTrigger = 0
    @State private var dragOffset: CGFloat = 0
    @FocusState private var explanationFocused: Bool

    private static let maxExplanationLength = 500

    init(
        word: Word,
        userProgress: UserProgress,
        isCompleted: Bool,
        latestExplanation: PracticedSentence?,
        onSubmit: @escaping (String, InputMethod, Bool) -> Void,
        onStageDidReachDone: @escaping () -> Void = {}
    ) {
        self.word = word
        self.userProgress = userProgress
        self.isCompleted = isCompleted
        self.latestExplanation = latestExplanation
        self.onSubmit = onSubmit
        self.onStageDidReachDone = onStageDidReachDone
        _stage = State(initialValue: isCompleted ? .done : .simple)
    }

    private var isComingSoon: Bool {
        word.simpleDefinition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || word.connector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var speechService: (any SpeechRepository)? { services?.speech }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            stageProgressBar
            headerRow
            stageContent
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(stage)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(x: 8, y: 0)),
                    removal: .opacity
                ))
            Spacer(minLength: 0)
            advanceControls
        }
        .padding(theme.spacing.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.colors.surface)
        .clipShape(.rect(cornerRadius: RadiusTokens.card))
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .stroke(theme.colors.line, lineWidth: 0.5)
        )
        .offset(x: dragOffset)
        .contentShape(Rectangle())
        .simultaneousGesture(swipeAdvanceGesture)
        .sensoryFeedback(.selection, trigger: advanceTrigger)
        .sheet(isPresented: $showReport) {
            WordReportSheet(word: word, userProgress: userProgress)
        }
        .sheet(isPresented: $showDetail) {
            NavigationStack {
                WordDetailView(word: word, userProgress: userProgress)
            }
        }
    }

    // MARK: - Stage progress bar (replaces stage counter chip — T3)

    private var stageProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.colors.line)
                Capsule()
                    .fill(theme.colors.accent)
                    .frame(width: geo.size.width * stageProgress)
                    .animation(reduceMotion ? nil : MotionTokens.standard, value: stageProgress)
            }
        }
        .frame(height: 2)
        .accessibilityLabel(String(format: String(localized: "a11y.feynman.stageProgress.format"),
                                   visibleStageIndex, visibleStageTotal))
    }

    /// 0-1 progress through visible stages.
    private var stageProgress: Double {
        Double(visibleStageIndex - 1) / Double(max(1, visibleStageTotal - 1))
    }

    private var visibleStageTotal: Int { isComingSoon ? 4 : 5 }

    private var visibleStageIndex: Int {
        switch stage {
        case .simple:    return 1
        case .technical: return 2
        case .explain:   return 3
        case .connector: return 4
        case .done:      return isComingSoon ? 4 : 5
        }
    }

    // MARK: - Header (T1/T3 — collapsed)

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.word)
                    .font(TypographyTokens.cardTitle)
                    .foregroundColor(theme.colors.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(word.pronunciation)
                    .font(TypographyTokens.mono)
                    .foregroundColor(theme.colors.inkMuted)
                    .accessibilityLabel(String(format: String(localized: "a11y.pronunciation.format"), word.pronunciation))
            }
            Spacer()
            overflowMenu
        }
    }

    /// T4 — single ⋯ replaces the three competing buttons on the word stage.
    private var overflowMenu: some View {
        Menu {
            Button {
                skipWord()
            } label: {
                Label(String(localized: "feynman.menu.skipMastered"),
                      systemImage: "checkmark.circle")
            }
            Button(role: .destructive) {
                reportAndSkip()
            } label: {
                Label(String(localized: "feynman.menu.report"),
                      systemImage: "flag")
            }
            if stage != .done {
                Divider()
                Button {
                    showDetail = true
                } label: {
                    Label(String(localized: "feynman.menu.openDetail"),
                          systemImage: "doc.text")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(.title3))
                .foregroundColor(theme.colors.inkFaint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "feynman.menu.label"))
    }

    // MARK: - Stage content

    @ViewBuilder
    private var stageContent: some View {
        switch stage {
        case .simple:    simpleStage
        case .connector: connectorStage
        case .explain:   explainStage
        case .technical: technicalStage
        case .done:      doneStage
        }
    }


    private var simpleStage: some View {
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

    private var connectorStage: some View {
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

    private var explainStage: some View {
        // ScrollView so the user can scroll to reach Submit when the
        // keyboard is up; `.scrollDismissesKeyboard(.interactively)` lets
        // them swipe the keyboard away with a downward drag.
        ScrollView {
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
        .scrollDismissesKeyboard(.interactively)
    }

    private var explanationEditor: some View {
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
    private func micButton(speech: any SpeechRepository) -> some View {
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

    private var technicalStage: some View {
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

    private var doneStage: some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            HStack(spacing: theme.spacing.sm) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(theme.colors.good)
                    .symbolEffect(.bounce, value: stage)
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

    // MARK: - Stage controls

    @ViewBuilder
    private var advanceControls: some View {
        switch stage {
        case .simple, .technical, .connector:
            SwipeContinueHint()
                .frame(maxWidth: .infinity)
                .accessibilityAction(named: Text("feynman.swipe.continue.a11y")) { advance() }
        case .explain:
            explainControls
        case .done:
            EmptyView()
        }
    }

    /// Stages where a left-swipe should move to the next stage. The explain
    /// stage is excluded because it owns a text editor + Submit button, and
    /// done is terminal.
    private var isSwipeAdvanceStage: Bool {
        switch stage {
        case .simple, .technical, .connector: return true
        case .explain, .done: return false
        }
    }

    /// Horizontal left-swipe advances the stage. Right-swipe is intentionally
    /// not handled — that gesture belongs to the navigation back-edge.
    private var swipeAdvanceGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                guard isSwipeAdvanceStage else { return }
                guard value.startLocation.x > Self.systemEdgeGutter else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy) * 1.5 else { return }
                // Track only leftward motion; apply rubber-band damping so the
                // card resists past the threshold instead of free-sliding.
                let leftward = min(dx, 0)
                dragOffset = leftward * 0.55
            }
            .onEnded { value in
                let resetAnimation: Animation? = reduceMotion ? nil : MotionTokens.snappy
                defer {
                    withAnimation(resetAnimation) { dragOffset = 0 }
                }
                guard isSwipeAdvanceStage else { return }
                guard value.startLocation.x > Self.systemEdgeGutter else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                let predictedDx = value.predictedEndTranslation.width
                let isHorizontal = abs(dx) > abs(dy) * 1.5
                let crossedThreshold = dx < -60 || predictedDx < -120
                if isHorizontal && crossedThreshold {
                    advance()
                }
            }
    }

    /// Width of the leading-edge gutter reserved for the system pop gesture.
    private static let systemEdgeGutter: CGFloat = 32

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
    }

    // MARK: - Actions

    private func advance() {
        guard let next = nextStage(from: stage) else { return }
        advanceTrigger &+= 1
        withAnimation(reduceMotion ? nil : MotionTokens.standard) {
            stage = next
        }
        if next == .done { onStageDidReachDone() }
    }

    /// Picks the next stage. word → simple → technical → explain → connector → done.
    /// Coming-soon words skip the connector stage.
    private func nextStage(from current: FeynmanStage) -> FeynmanStage? {
        switch current {
        case .simple:    return .technical
        case .technical: return .explain
        case .explain:   return isComingSoon ? .done : .connector
        case .connector: return .done
        case .done:      return nil
        }
    }

    private func submitExplanation(trimmed: String) {
        stopRecordingIfNeeded()
        onSubmit(trimmed, inputMethod, false)
        advanceTrigger &+= 1
        let next: FeynmanStage = isComingSoon ? .done : .connector
        withAnimation(reduceMotion ? nil : MotionTokens.standard) {
            stage = next
        }
        if next == .done { onStageDidReachDone() }
    }

    private func submitAsComingSoon() {
        stopRecordingIfNeeded()
        onSubmit("", .typed, false)
        advanceTrigger &+= 1
        withAnimation(reduceMotion ? nil : MotionTokens.standard) {
            stage = .done
        }
        onStageDidReachDone()
    }

    private func skipWord() {
        stopRecordingIfNeeded()
        onSubmit("", .typed, true)  // mark as mastered
        advanceTrigger &+= 1
        withAnimation(reduceMotion ? nil : MotionTokens.standard) {
            stage = .done
        }
        onStageDidReachDone()
    }

    private func reportAndSkip() {
        showReport = true
        stopRecordingIfNeeded()
        onSubmit("", .typed, true)
        advanceTrigger &+= 1
        withAnimation(reduceMotion ? nil : MotionTokens.standard) {
            stage = .done
        }
        onStageDidReachDone()
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

    /// F4 — sentence-case stage labels. Reduced from the previous tracked
    /// uppercase caption to a small medium-weight label.
    private func stageLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(TypographyTokens.subheadline.weight(.medium))
            .foregroundColor(theme.colors.inkMuted)
    }

    @ViewBuilder
    private func section<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            SectionHeader(title: title)
            content()
        }
    }
}

/// Replaces the per-stage advance CTA. Quietly tells the user to swipe left
/// to move on; the chevron nudges leftward in time with the gesture direction.
private struct SwipeContinueHint: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var nudge = false

    var body: some View {
        HStack(spacing: 6) {
            Text("feynman.swipe.continue")
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
            Image(systemName: "chevron.left")
                .font(TypographyTokens.callout.weight(.semibold))
                .foregroundColor(theme.colors.inkMuted)
                .offset(x: nudge ? -4 : 0)
        }
        .frame(height: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "feynman.swipe.continue"))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                nudge = true
            }
        }
    }
}
