import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.stackspeak.ios", category: "App")

@main
struct StackSpeakApp: App {
    let modelContainer: ModelContainer?
    let themeManager = ThemeManager()
    let services: Services?
    let initError: Error?

    init() {
        var container: ModelContainer?
        var error: Error?

        do {
            let schema = Schema([
                Word.self,
                DailySet.self,
                UserProgress.self,
                PracticedSentence.self,
                ReviewState.self,
                AssessmentResult.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch let caught {
            logger.error("Failed to initialize ModelContainer: \(caught.localizedDescription)")
            error = caught
        }

        self.modelContainer = container
        self.initError = error
        self.services = container.map { Services(modelContext: $0.mainContext) }

        TypographyTokens.assertCustomFontsLoaded()
    }

    var body: some Scene {
        WindowGroup {
            if let error = initError {
                ErrorView(error: error)
                    .withTheme(themeManager)
            } else if let container = modelContainer, let services = services {
                ContentView()
                    .modelContainer(container)
                    .withTheme(themeManager)
                    .environment(\.services, services)
                    .task {
                        await initializeApp()
                    }
            } else {
                ProgressView()
                    .withTheme(themeManager)
            }
        }
    }

    @MainActor
    private func initializeApp() async {
        guard let container = modelContainer else { return }
        let context = container.mainContext

        let descriptor = FetchDescriptor<UserProgress>()
        let progress = try? context.fetch(descriptor).first

        if let progress {
            themeManager.preference = progress.themePreference
            themeManager.density = progress.densityPreference

            // Rebuild the two-correct cache on launch in case it was lost or corrupted.
            if progress.wordsWithTwoCorrectIds.isEmpty && !progress.assessmentResults.isEmpty {
                progress.rebuildTwoCorrectCache()
                do { try context.save() } catch { logger.error("Cache rebuild save failed: \(error)") }
            }
        } else {
            // Race-safe singleton check: only insert if count is truly zero
            let count = (try? context.fetchCount(descriptor)) ?? 0
            if count == 0 {
                let newProgress = UserProgress()
                context.insert(newProgress)
                do { try context.save() } catch { logger.error("UserProgress init save failed: \(error)") }
            } else {
                logger.warning("UserProgress creation skipped - already exists (race avoided)")
            }
        }

        if let services = services {
            do { try await services.word.loadWordsFromBundle() } catch { logger.error("Word bundle load failed: \(error)") }
        }
    }
}

struct ErrorView: View {
    @Environment(\.theme) private var theme
    let error: Error

    var body: some View {
        ZStack {
            theme.colors.bg.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(theme.colors.warn)

                Text("Unable to Start")
                    .font(TypographyTokens.title1)
                    .foregroundColor(theme.colors.ink)

                Text("StackSpeak encountered an error initializing the database. Please restart the app or reinstall if the problem persists.")
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(error.localizedDescription)
                    .font(TypographyTokens.mono)
                    .foregroundColor(theme.colors.inkFaint)
                    .padding()
                    .background(theme.colors.surface)
                    .cornerRadius(8)
                    .padding(.horizontal, 32)

                Button(action: {
                    // User can try force-quitting and restarting
                    fatalError("User requested crash to restart")
                }) {
                    Text("Restart App")
                        .font(TypographyTokens.headline)
                        .foregroundColor(theme.colors.accentText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.colors.accent)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
            }
        }
    }
}

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

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("home.tab", systemImage: "house.fill") }

            ReviewView()
                .tabItem { Label("review.tab", systemImage: "brain.fill") }

            LibraryView()
                .tabItem { Label("library.tab", systemImage: "books.vertical.fill") }

            ProfileView()
                .tabItem { Label("profile.tab", systemImage: "person.fill") }
        }
    }
}
