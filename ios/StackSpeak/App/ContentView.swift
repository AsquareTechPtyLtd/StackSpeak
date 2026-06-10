import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Query private var userProgressList: [UserProgress]

    @State private var showOnboarding = false

    var userProgress: UserProgress? {
        userProgressList.first
    }

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding)
            } else {
                MainTabView()
            }
        }
        .environment(\.userProgress, userProgress)
        .task {
            checkOnboardingStatus()
        }
        // Keep ThemeManager aware of the system color scheme so `theme.colors` responds to
        // dark/light mode changes when the user has "System" preference set.
        .onChange(of: systemColorScheme, initial: true) { _, newValue in
            theme.systemColorScheme = newValue
        }
        // Fix race condition: checkOnboardingStatus may run before UserProgress is created.
        // Re-check whenever userProgressList updates.
        .onChange(of: userProgressList) { _, _ in
            checkOnboardingStatus()
        }
        // Re-check notification authorization when app comes to foreground
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    _ = await NotificationService.shared.checkAuthorizationStatus()
                }
            }
        }
    }

    private func checkOnboardingStatus() {
        guard let progress = userProgress else { return }
        showOnboarding = !progress.didCompleteOnboarding
    }
}
