import SwiftUI
import SwiftData
import OSLog

struct OnboardingView: View {
    @Environment(\.theme) private var theme
    @Environment(\.userProgress) private var userProgress
    @Environment(\.modelContext) private var modelContext

    @Binding var showOnboarding: Bool
    private let logger = Logger(subsystem: "com.stackspeak.ios", category: "Onboarding")
    @State private var currentPage = 0
    @State private var showStackSelection = false

    private let pages = [
        OnboardingPage(
            title: String(localized: "onboarding.page1.title"),
            description: String(localized: "onboarding.page1.description"),
            systemImage: "sparkles"
        ),
        OnboardingPage(
            title: String(localized: "onboarding.page2.title"),
            description: String(localized: "onboarding.page2.description"),
            systemImage: "mic.fill"
        ),
        OnboardingPage(
            title: String(localized: "onboarding.page3.title"),
            description: String(localized: "onboarding.page3.description"),
            systemImage: "chart.line.uptrend.xyaxis"
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
                Spacer()

                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(page: pages[index]).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Spacer()

                VStack(spacing: theme.spacing.lg) {
                    Button(action: advance) {
                        Text(currentPage == pages.count - 1
                             ? String(localized: "onboarding.button.getStarted")
                             : String(localized: "onboarding.button.next"))
                            .font(TypographyTokens.headline)
                            .foregroundColor(theme.colors.accentText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacing.lg)
                            .background(theme.colors.accent)
                            .cornerRadius(12)
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

    private func advance() {
        if currentPage < pages.count - 1 {
            withAnimation { currentPage += 1 }
        } else {
            showStackSelection = true
        }
    }

    /// Skips all onboarding, selects mandatory stacks, and goes straight to the home screen.
    private func skipAll() {
        if let progress = userProgress {
            // Ensure mandatory stacks are selected even when the user skips stack selection.
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
            Image(systemName: page.systemImage)
                .font(.system(size: 72, weight: .light))
                .foregroundColor(theme.colors.accent)
                .padding(.bottom, theme.spacing.lg)
                .accessibilityHidden(true)

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
        .padding(.vertical, theme.spacing.xxxl)
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let systemImage: String
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
