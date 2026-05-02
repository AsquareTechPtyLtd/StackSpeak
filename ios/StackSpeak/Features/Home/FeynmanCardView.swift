import SwiftUI

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
///
/// Implementation is split across files for readability:
/// - `FeynmanCardView.swift` (this file) — main view, header, progress bar
/// - `FeynmanCardView+Stages.swift` — stage views (simple/connector/technical/done)
/// - `FeynmanCardView+Explain.swift` — explain stage + editor + mic + controls
/// - `FeynmanCardView+Actions.swift` — actions, gestures, recording
struct FeynmanCardView: View {
    @Environment(\.theme) var theme
    @Environment(\.services) var services
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let word: Word
    let userProgress: UserProgress
    let isCompleted: Bool
    let latestExplanation: PracticedSentence?
    let onSubmit: (String, InputMethod, Bool) -> Void  // explanation, inputMethod, markAsMastered
    /// Optional — fires whenever the card reaches the `done` stage (either
    /// via submit, skip, or report). Used by `WordFeynmanScreen` to surface
    /// a post-completion CTA. Default is no-op so other call sites stay simple.
    let onStageDidReachDone: () -> Void

    @State var stage: FeynmanStage
    @State var explanation: String = ""
    @State var inputMethod: InputMethod = .typed
    @State var micError: String?
    @State var showReport = false
    @State var showDetail = false
    @State var advanceTrigger = 0
    @State var dragOffset: CGFloat = 0
    @FocusState var explanationFocused: Bool

    static let maxExplanationLength = 500

    /// Width of the leading-edge gutter reserved for the system pop gesture.
    static let systemEdgeGutter: CGFloat = 32

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

    var isComingSoon: Bool {
        word.simpleDefinition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || word.connector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var speechService: (any SpeechRepository)? { services?.speech }

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
            WordReportSheet(
                word: word,
                userProgress: userProgress,
                onSubmitted: finalizeReportSkip
            )
        }
        .sheet(isPresented: $showDetail) {
            NavigationStack {
                WordDetailView(
                    word: word,
                    userProgress: userProgress,
                    showsDoneButton: true
                )
            }
        }
    }

    // MARK: - Stage progress bar (T3 — replaces stage counter chip)

    private var stageProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.colors.line)
                Capsule()
                    .fill(theme.colors.accentDecoration)
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
            if previousStage(from: stage) != nil {
                backButton
            }
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

    private var backButton: some View {
        Button(action: retreat) {
            Image(systemName: "chevron.left")
                .font(.system(.title3, weight: .semibold))
                .foregroundColor(theme.colors.inkFaint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("a11y.feynman.previousStage"))
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

    // MARK: - Stage advance controls (bottom of card)

    @ViewBuilder
    var advanceControls: some View {
        switch stage {
        case .simple, .technical, .connector:
            SwipeNudge("feynman.swipe.continue", direction: .backward, onAdvance: advance)
                .accessibilityAction(named: Text("feynman.swipe.continue.a11y")) { advance() }
        case .explain:
            explainControls
        case .done:
            EmptyView()
        }
    }
}
