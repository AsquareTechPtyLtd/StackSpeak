import SwiftUI

struct OnboardingView: View {
    @Environment(\.theme) private var theme
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0
    @State private var showStackSelection = false

    private let pages = [
        OnboardingPage(
            title: "Five quiet words,\nevery weekday.",
            description: "Carefully chosen technical vocabulary delivered daily to expand your professional communication skills.",
            systemImage: "sparkles"
        ),
        OnboardingPage(
            title: "Practice by writing—\nor speaking.",
            description: "Use each word in your own sentence. Type it out or speak it aloud. Active learning builds lasting memory.",
            systemImage: "mic.fill"
        ),
        OnboardingPage(
            title: "Level up from Intern\nto Staff Engineer.",
            description: "Unlock more words as you build streaks and practice consistently. Your vocabulary journey mirrors your career path.",
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
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Spacer()

                VStack(spacing: theme.spacing.lg) {
                    Button(action: advance) {
                        Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                            .font(TypographyTokens.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacing.lg)
                            .background(theme.colors.accent)
                            .cornerRadius(12)
                    }

                    Button(action: skip) {
                        Text("Skip")
                            .font(TypographyTokens.callout)
                            .foregroundColor(theme.colors.inkMuted)
                    }
                }
                .padding(.horizontal, theme.spacing.xl)
                .padding(.bottom, theme.spacing.xl)
            }
        }
    }

    private func advance() {
        if currentPage < pages.count - 1 {
            withAnimation {
                currentPage += 1
            }
        } else {
            showStackSelection = true
        }
    }

    private func skip() {
        showStackSelection = true
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
