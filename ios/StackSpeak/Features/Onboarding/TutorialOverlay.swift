import SwiftUI

/// First-time-user tutorial overlay primitive — see
/// `ui-ux-tutorial-design-2026-05-01.md` for the council-arbitrated spec.
///
/// Renders, when `viewModel.currentStep != nil`:
/// - Dimmed scrim (`bg @ 0.78`) with feathered RadialGradient lens cutout.
/// - 1pt accent border ring + accentBg inner bloom around the lens (§4).
/// - Top-right "Skip tour" button + confirmation dialog (§3).
/// - Bottom-anchored instruction card (`maxWidth: 520`, surface bg, 0.5pt
///   line hairline, no shadow) with title/body/step counter chip (§4–§5).
/// - Optional "Tap when ready" idle hint and "Tap the highlighted button."
///   wrong-tap nudge appended to the body (§6, §7).
///
/// **Stateless w.r.t. step progression** — `TutorialViewModel` owns step
/// state, persistence, idle timer, and wrong-tap counting (Task #4).
///
/// **Anchor resolution is the host's responsibility.** The host
/// (`WordFeynmanScreen`, Task #6) reads `TutorialAnchorPreferenceKey` via
/// `.overlayPreferenceValue(...)`, resolves the current target's
/// `Anchor<CGRect>` against the surrounding `GeometryProxy`, and passes
/// the concrete CGRect down via `targetRect`.
struct TutorialOverlay: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var viewModel: TutorialViewModel
    /// Resolved rect of the current spotlight target in the overlay's
    /// coordinate space. `nil` while dismissed or while anchors haven't
    /// been measured yet.
    let targetRect: CGRect?

    @State private var borderPulseOpacity: Double = 1.0
    @AccessibilityFocusState private var instructionFocused: Bool

    private let lensPadding: CGFloat = 16
    private let leadingSystemGutter: CGFloat = 32
    private let instructionCardMaxWidth: CGFloat = 520

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if viewModel.currentStep != nil {
                    scrimLayer(in: proxy.size)

                    if let rect = paddedLensRect(in: proxy.size) {
                        lensTint(in: rect)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                        lensBorder(in: rect)
                            .opacity(borderPulseOpacity)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }

                    chromeOverlay(in: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : MotionTokens.standard, value: viewModel.currentStep)
        .animation(reduceMotion ? nil : MotionTokens.snappy, value: targetRect)
        .onChange(of: viewModel.pulseToken) { _, _ in
            triggerBorderPulse()
        }
        .onChange(of: viewModel.currentStep) { _, newStep in
            guard newStep != nil else { return }
            // Re-focus VoiceOver onto the instruction card on each step
            // change (§6 — per-step `.screenChanged`-equivalent narration).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                instructionFocused = true
            }
        }
        .confirmationDialog(
            "tutorial.skip.title",
            isPresented: $viewModel.showSkipDialog,
            titleVisibility: .visible
        ) {
            Button("tutorial.skip.confirm", role: .destructive) {
                viewModel.confirmSkip()
            }
            Button("tutorial.skip.cancel", role: .cancel) {
                viewModel.cancelSkip()
            }
        } message: {
            Text("tutorial.skip.message")
        }
    }

    // MARK: - Lens geometry

    private func paddedLensRect(in screenSize: CGSize) -> CGRect? {
        guard let raw = targetRect, raw.width > 0, raw.height > 0 else { return nil }
        return raw.insetBy(dx: -lensPadding, dy: -lensPadding)
    }

    /// Adaptive lens shape: circle for compact targets (aspect ratio ≈ 1),
    /// horizontally-stretched ellipse for wide targets (§4). Implemented via
    /// `Ellipse` always — when the rect is square the ellipse degenerates to
    /// a circle, so no shape switch is needed.
    private func lensShape() -> Ellipse {
        Ellipse()
    }

    // MARK: - Scrim with feathered cutout

    private func scrimLayer(in size: CGSize) -> some View {
        let lens = paddedLensRect(in: size)

        return theme.colors.bg
            .opacity(0.78)
            .mask {
                ZStack {
                    Rectangle().fill(Color.white)
                    if let lens {
                        // Feathered RadialGradient — black at center fades
                        // to clear at edge. Combined with .destinationOut
                        // this erases a soft hole in the white mask.
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: .black, location: 0.0),
                                .init(color: .black, location: 0.62),
                                .init(color: .clear, location: 1.0)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: max(lens.width, lens.height) * 0.55
                        )
                        .frame(width: lens.width * 1.35, height: lens.height * 1.35)
                        .position(x: lens.midX, y: lens.midY)
                        .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()
            }
            .contentShape(
                ScrimHitShape(
                    cutoutRect: lens,
                    leadingGutterWidth: leadingSystemGutter,
                    instructionCardExclusionHeight: instructionCardExclusionHeight(for: size)
                ),
                eoFill: true
            )
            .onTapGesture {
                viewModel.handleScrimWrongTap()
            }
            .accessibilityHidden(true)
    }

    /// Conservative bottom strip excluded from the wrong-tap hit area so
    /// taps on the instruction card never get re-routed to the scrim.
    /// Generous (240pt) — false negatives (a tap just above the card
    /// counted as a wrong-tap) are worse than false positives.
    private func instructionCardExclusionHeight(for size: CGSize) -> CGFloat {
        min(280, size.height * 0.42)
    }

    // MARK: - Lens tint + border ring

    private func lensTint(in rect: CGRect) -> some View {
        lensShape()
            .fill(theme.colors.accentBg)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    private func lensBorder(in rect: CGRect) -> some View {
        lensShape()
            .stroke(theme.colors.accent, lineWidth: 1)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    // MARK: - Chrome (skip + instruction card)

    private func chromeOverlay(in size: CGSize) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                skipButton
            }
            .padding(.trailing, theme.spacing.lg)
            .padding(.top, theme.spacing.sm)

            Spacer(minLength: 0)

            instructionCard
                .frame(maxWidth: instructionCardMaxWidth)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, theme.spacing.lg)
                .padding(.bottom, theme.spacing.lg)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    private var skipButton: some View {
        Button {
            viewModel.handleSkipTap()
        } label: {
            Text("tutorial.skip.button")
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.accent)
                .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "a11y.tutorial.skip"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Instruction card

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(stepTitleKey)
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.ink)
                Spacer(minLength: theme.spacing.md)
                Text(stepCounterText)
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkMuted)
                    .accessibilityHidden(true)
            }

            Text(stepBodyMarkdown)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
                .lineSpacing(10)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.showIdleHint || (reduceMotion && viewModel.showIdleHint) {
                Text("tutorial.idleHint")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.ink)
                    .padding(.top, theme.spacing.xs)
                    .accessibilityLabel(String(localized: "a11y.tutorial.idleHint"))
            }
        }
        .padding(theme.spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.surface)
        .clipShape(.rect(cornerRadius: RadiusTokens.card))
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .stroke(theme.colors.line, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityNarration)
        .accessibilityAddTraits(.isHeader)
        .accessibilityFocused($instructionFocused)
    }

    private var stepTitleKey: LocalizedStringKey {
        switch viewModel.currentStep {
        case .s1: return "tutorial.step1.title"
        case .s2: return "tutorial.step2.title"
        case nil: return ""
        }
    }

    /// Body text. When `showWrongTapHint` is true (after 2 misses in 8s)
    /// the literal nudge from §7 is appended in the same paragraph.
    private var stepBodyMarkdown: AttributedString {
        let baseKey: String
        switch viewModel.currentStep {
        case .s1: baseKey = "tutorial.step1.body"
        case .s2: baseKey = "tutorial.step2.body"
        case nil: return AttributedString("")
        }
        var combined = String(localized: String.LocalizationValue(baseKey))
        if viewModel.showWrongTapHint {
            combined += " " + String(localized: "tutorial.wrongTap.hint")
        }
        // Markdown rendering for the **bold** literal button labels in §5.
        return (try? AttributedString(markdown: combined)) ?? AttributedString(combined)
    }

    private var stepCounterText: String {
        String(format: String(localized: "tutorial.step.counter.format"),
               viewModel.stepNumber, viewModel.totalSteps)
    }

    private var accessibilityNarration: String {
        let stepCounter = String(format: String(localized: "a11y.tutorial.step.counter.format"),
                                 viewModel.stepNumber, viewModel.totalSteps)
        let title = String(localized: String.LocalizationValue(stepTitleLocalizationKey))
        let body = stepBodyPlainText
        let idle = viewModel.showIdleHint ? " " + String(localized: "a11y.tutorial.idleHint") : ""
        return "\(stepCounter). \(title). \(body)\(idle)"
    }

    private var stepTitleLocalizationKey: String {
        switch viewModel.currentStep {
        case .s1: return "tutorial.step1.title"
        case .s2: return "tutorial.step2.title"
        case nil: return ""
        }
    }

    /// Plain-text body for VoiceOver — strips the markdown asterisks so the
    /// label reads naturally. The visual bold treatment is preserved by the
    /// rendered `AttributedString`.
    private var stepBodyPlainText: String {
        let baseKey: String
        switch viewModel.currentStep {
        case .s1: baseKey = "tutorial.step1.body"
        case .s2: baseKey = "tutorial.step2.body"
        case nil: return ""
        }
        var combined = String(localized: String.LocalizationValue(baseKey))
        if viewModel.showWrongTapHint {
            combined += " " + String(localized: "tutorial.wrongTap.hint")
        }
        return combined.replacingOccurrences(of: "**", with: "")
    }

    // MARK: - Border pulse animation

    /// Single-shot 240ms snappy opacity pulse 1.0→0.6→1.0 per §6.
    /// Used by both wrong-tap and 8s-idle re-cue paths. Skipped under
    /// Reduced Motion — the static "Tap when ready" hint carries the
    /// content there (§6 binding rider).
    private func triggerBorderPulse() {
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.12)) {
            borderPulseOpacity = 0.6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.12)) {
                borderPulseOpacity = 1.0
            }
        }
    }
}

// MARK: - Previews

private struct TutorialPreviewHarness: View {
    let step: TutorialViewModel.Step
    var idleHint: Bool = false
    var wrongTapHint: Bool = false

    @State private var vm = TutorialViewModel()
    @State private var theme = ThemeManager()

    var body: some View {
        GeometryReader { proxy in
            let targetRect = mockTargetRect(in: proxy.size)
            ZStack {
                theme.colors.bg.ignoresSafeArea()

                // Placeholder card body — illustrates how the spotlight
                // reveals underlying content through the cutout.
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    Text("supplant")
                        .font(TypographyTokens.cardTitle)
                        .foregroundColor(theme.colors.ink)
                    Text("/səˈplant/")
                        .font(TypographyTokens.mono)
                        .foregroundColor(theme.colors.inkMuted)
                    Text("To replace one thing with another, often by force or by being more useful.")
                        .font(TypographyTokens.body)
                        .foregroundColor(theme.colors.ink)
                        .lineSpacing(8)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Rectangle()
                        .fill(theme.colors.surface)
                        .overlay(RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .stroke(theme.colors.line, lineWidth: 0.5))
                        .frame(height: 50)
                }
                .padding(theme.spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                TutorialOverlay(viewModel: vm, targetRect: targetRect)
            }
            .environment(\.theme, theme)
            .onAppear {
                vm.currentStep = step
                vm.showIdleHint = idleHint
                vm.showWrongTapHint = wrongTapHint
            }
        }
    }

    private func mockTargetRect(in size: CGSize) -> CGRect {
        switch step {
        case .s1:
            // SwipeNudge-shaped: wide horizontal strip near the bottom.
            return CGRect(x: 24, y: size.height - 180,
                          width: size.width - 48, height: 56)
        case .s2:
            // Explain composite: tall block in the upper-middle.
            return CGRect(x: 24, y: size.height * 0.32,
                          width: size.width - 48, height: size.height * 0.32)
        }
    }
}

#Preview("S1 spotlight — light") {
    TutorialPreviewHarness(step: .s1)
        .preferredColorScheme(.light)
}

#Preview("S1 spotlight — dark") {
    TutorialPreviewHarness(step: .s1)
        .preferredColorScheme(.dark)
}

#Preview("S2 composite — light") {
    TutorialPreviewHarness(step: .s2)
        .preferredColorScheme(.light)
}

#Preview("S2 composite — dark") {
    TutorialPreviewHarness(step: .s2)
        .preferredColorScheme(.dark)
}

#Preview("S1 — Dynamic Type AX5") {
    TutorialPreviewHarness(step: .s1)
        .preferredColorScheme(.light)
        .dynamicTypeSize(.accessibility5)
}

#Preview("S1 — Dynamic Type Large") {
    TutorialPreviewHarness(step: .s1)
        .preferredColorScheme(.light)
        .dynamicTypeSize(.large)
}

// `accessibilityReduceMotion` is read-only in the environment, so the
// Reduced Motion fork can't be flipped on from a preview directly. Toggle
// it via the simulator's Settings → Accessibility → Motion → Reduce
// Motion to verify the §6 binding-rider behavior. The preview below
// renders the static "Tap when ready" surface that Reduced Motion users
// see when the 8s idle window elapses.
#Preview("S1 — idle hint surfaced") {
    TutorialPreviewHarness(step: .s1, idleHint: true)
        .preferredColorScheme(.light)
}

#Preview("S1 — wrong-tap hint appended") {
    TutorialPreviewHarness(step: .s1, wrongTapHint: true)
        .preferredColorScheme(.light)
}

// MARK: - Even-odd hit shape for the scrim

/// Produces a Path that fills the screen rect MINUS the spotlight cutout,
/// the leading 32pt system-edge gutter (preserves NavigationStack swipe-back
/// per §7), and a generous bottom exclusion zone for the instruction card.
/// Used as the `contentShape` of the scrim so wrong-taps register only in
/// the dimmed gutter — taps on the spotlight pass through to the underlying
/// card; taps on the instruction card hit its own buttons.
private struct ScrimHitShape: Shape {
    let cutoutRect: CGRect?
    let leadingGutterWidth: CGFloat
    let instructionCardExclusionHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)

        // Subtract leading system gutter.
        path.addRect(CGRect(x: rect.minX,
                            y: rect.minY,
                            width: leadingGutterWidth,
                            height: rect.height))

        // Subtract bottom instruction-card exclusion.
        path.addRect(CGRect(x: rect.minX,
                            y: rect.maxY - instructionCardExclusionHeight,
                            width: rect.width,
                            height: instructionCardExclusionHeight))

        // Subtract the spotlight cutout (ellipse).
        if let cutoutRect {
            path.addEllipse(in: cutoutRect)
        }

        return path
    }
}
