import SwiftUI
import SwiftData
import OSLog

/// O1 — replaces the system page-indicator dots (which get lost on the cream
/// background) with a hairline 3-segment progress bar at the top of the screen.
struct OnboardingView: View {
    @Environment(\.theme) private var theme
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext

    @Binding var showOnboarding: Bool
    private let logger = Logger(subsystem: "com.stackspeak.ios", category: "Onboarding")
    @State private var currentPage = 0
    @State private var showStackSelection = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            kind: .icon(systemImage: "sparkles"),
            title: String(localized: "onboarding.page1.title"),
            description: String(localized: "onboarding.page1.description")
        ),
        OnboardingPage(
            kind: .icon(systemImage: "mic.fill"),
            title: String(localized: "onboarding.page2.title"),
            description: String(localized: "onboarding.page2.description")
        ),
        OnboardingPage(
            kind: .sampleCard,
            title: String(localized: "onboarding.page3.title"),
            description: String(localized: "onboarding.page3.description")
        ),
        OnboardingPage(
            kind: .icon(systemImage: "chart.line.uptrend.xyaxis"),
            title: String(localized: "onboarding.page4.title"),
            description: String(localized: "onboarding.page4.description")
        )
    ]

    var body: some View {
        Group {
            if showStackSelection {
                StackSelectionView(showOnboarding: $showOnboarding)
            } else {
                onboardingPages
            }
        }
    }

    private var onboardingPages: some View {
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, theme.spacing.xl)
                    .padding(.top, theme.spacing.lg)

                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(page: pages[index]).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: theme.spacing.lg) {
                    PrimaryCTAButton(currentPage == pages.count - 1
                                     ? "onboarding.button.getStarted"
                                     : "onboarding.button.next") {
                        advance()
                    }

                    Button(action: skipAll) {
                        Text("onboarding.button.skip")
                            .font(TypographyTokens.callout)
                            .foregroundColor(theme.colors.inkMuted)
                    }
                    .accessibilityLabel(String(localized: "a11y.skipOnboarding"))
                }
                .padding(.horizontal, theme.spacing.xl)
                .padding(.bottom, theme.spacing.xl)
            }
        }
    }

    /// O1 — three thin segments. Filled segments = pages already seen +
    /// the current one.
    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= currentPage ? theme.colors.accent : theme.colors.line)
                    .frame(height: 3)
                    .animation(MotionTokens.standard, value: currentPage)
            }
        }
        .accessibilityLabel(String(format: String(localized: "a11y.onboarding.progress.format"),
                                   currentPage + 1, pages.count))
    }

    private func advance() {
        if currentPage < pages.count - 1 {
            withAnimation(MotionTokens.standard) { currentPage += 1 }
        } else {
            showStackSelection = true
        }
    }

    /// Skips all onboarding, selects mandatory stacks, and goes straight to
    /// the home screen.
    private func skipAll() {
        if let progress = userProgress {
            let mandatory = Set(WordStack.mandatoryStacks(for: progress.level).map { $0.rawValue })
            if progress.selectedStacks.isEmpty {
                progress.selectedStacks = mandatory
            } else {
                var updated = progress.selectedStacks
                updated.formUnion(mandatory)
                progress.selectedStacks = updated
            }
            progress.didCompleteOnboarding = true
            do {
                try modelContext.save()
            } catch {
                logger.error("Failed to save onboarding skip: \(error.localizedDescription, privacy: .public)")
            }
        }
        showOnboarding = false
    }
}

struct OnboardingPageView: View {
    @Environment(\.theme) private var theme
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: theme.spacing.xl) {
            switch page.kind {
            case .icon(let symbol):
                Image(systemName: symbol)
                    .font(.system(size: 72, weight: .light))
                    .foregroundColor(theme.colors.accent)
                    .padding(.bottom, theme.spacing.lg)
                    .accessibilityHidden(true)
            case .sampleCard:
                SampleFeynmanPreview()
                    .padding(.horizontal, theme.spacing.xl)
                    .padding(.bottom, theme.spacing.lg)
            }

            Text(page.title)
                .font(TypographyTokens.title1)
                .foregroundColor(theme.colors.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.xl)

            Text(page.description)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.xxxl)
        }
        .padding(.vertical, theme.spacing.xl)
    }
}

struct OnboardingPage {
    enum Kind {
        case icon(systemImage: String)
        case sampleCard
    }
    let kind: Kind
    let title: String
    let description: String
}

/// CC1 — non-interactive teaser of the actual Feynman card. New users see a
/// real card before they read about it. Hard-coded sample word so we don't
/// depend on the catalog being loaded yet.
private struct SampleFeynmanPreview: View {
    @Environment(\.theme) private var theme
    @State private var stage: SampleStage = .word

    enum SampleStage: Int, CaseIterable { case word, plain, technical }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack(spacing: 4) {
                ForEach(SampleStage.allCases, id: \.rawValue) { s in
                    Capsule()
                        .fill(s.rawValue <= stage.rawValue ? theme.colors.accent : theme.colors.line)
                        .frame(height: 2)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Idempotent")
                    .font(TypographyTokens.title3)
                    .foregroundColor(theme.colors.ink)
                Text("eye-DEM-po-tent")
                    .font(TypographyTokens.mono)
                    .foregroundColor(theme.colors.inkMuted)
            }
            stageBody
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(stage)
                .transition(.opacity)
            Spacer(minLength: 0)
        }
        .padding(theme.spacing.lg)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(theme.colors.surface)
        .clipShape(.rect(cornerRadius: RadiusTokens.card))
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .stroke(theme.colors.line, lineWidth: 0.5)
        )
        .onTapGesture { advance() }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Tap to advance the demo")
    }

    @ViewBuilder
    private var stageBody: some View {
        switch stage {
        case .word:
            Text("Tap to see what it means.")
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
        case .plain:
            Text("Doing it again won't change the result — like pressing the ground-floor button in an elevator that's already there.")
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
                .fixedSize(horizontal: false, vertical: true)
        case .technical:
            Text("An operation that produces the same result no matter how many times it runs.")
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func advance() {
        let next = SampleStage(rawValue: (stage.rawValue + 1) % SampleStage.allCases.count) ?? .word
        withAnimation(MotionTokens.standard) { stage = next }
    }
}

#Preview("Onboarding - Light") {
    OnboardingView(showOnboarding: .constant(true))
        .withTheme(ThemeManager())
}

#Preview("Onboarding - Dark") {
    OnboardingView(showOnboarding: .constant(true))
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
