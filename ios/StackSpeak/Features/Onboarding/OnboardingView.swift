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
            kind: .icon(systemImage: "bubble.left.and.bubble.right"),
            title: String(localized: "onboarding.page1.title"),
            description: String(localized: "onboarding.page1.description")
        ),
        OnboardingPage(
            kind: .icon(systemImage: "shuffle"),
            title: String(localized: "onboarding.page2.title"),
            description: String(localized: "onboarding.page2.description")
        ),
        OnboardingPage(
            kind: .icon(systemImage: "mic.fill"),
            title: String(localized: "onboarding.page3.title"),
            description: String(localized: "onboarding.page3.description")
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
                    if currentPage == pages.count - 1 {
                        PrimaryCTAButton("onboarding.button.getStarted") {
                            advance()
                        }
                    } else {
                        SwipeHint(onAdvance: advance)

                        Button(action: skipAll) {
                            Text("onboarding.button.skip")
                                .font(TypographyTokens.callout)
                                .foregroundColor(theme.colors.inkMuted)
                        }
                        .accessibilityLabel(String(localized: "a11y.skipOnboarding"))
                    }
                }
                .padding(.horizontal, theme.spacing.xl)
                .padding(.bottom, theme.spacing.xl)
                .animation(MotionTokens.standard, value: currentPage)
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
    }
    let kind: Kind
    let title: String
    let description: String
}

private struct SwipeHint: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var nudge = false

    let onAdvance: () -> Void

    var body: some View {
        Button(action: onAdvance) {
            HStack(spacing: 6) {
                Text("onboarding.swipeHint")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
                Image(systemName: "chevron.right")
                    .font(TypographyTokens.callout.weight(.semibold))
                    .foregroundColor(theme.colors.inkMuted)
                    .offset(x: nudge ? 4 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "onboarding.swipeHint"))
        .accessibilityAddTraits(.isButton)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                nudge = true
            }
        }
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
