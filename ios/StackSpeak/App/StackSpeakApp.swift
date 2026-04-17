import SwiftUI
import SwiftData

@main
struct StackSpeakApp: App {
    let modelContainer: ModelContainer
    let themeManager = ThemeManager()

    init() {
        do {
            let schema = Schema([
                Word.self,
                DailySet.self,
                UserProgress.self,
                PracticedSentence.self,
                ReviewState.self,
                AssessmentResult.self
            ])

            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .withTheme(themeManager)
                .task {
                    await initializeApp()
                }
        }
    }

    @MainActor
    private func initializeApp() async {
        let context = modelContainer.mainContext

        let descriptor = FetchDescriptor<UserProgress>()
        if let existingProgress = try? context.fetch(descriptor).first {
            themeManager.preference = existingProgress.themePreference
            themeManager.density = existingProgress.densityPreference
        } else {
            let newProgress = UserProgress()
            context.insert(newProgress)
            try? context.save()
        }

        let wordService = WordService(modelContext: context)
        try? await wordService.loadWordsFromBundle()
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
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
        .task {
            checkOnboardingStatus()
        }
    }

    private func checkOnboardingStatus() {
        if let progress = userProgress {
            let hasCompletedOnboarding = progress.wordsPracticedCount > 0 || progress.lastCompletedDate != nil
            showOnboarding = !hasCompletedOnboarding
        }
    }
}

struct MainTabView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Today", systemImage: "house.fill")
                }

            ReviewView()
                .tabItem {
                    Label("Review", systemImage: "brain.fill")
                }

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }

            ProfileView()
                .tabItem {
                    Label("You", systemImage: "person.fill")
                }
        }
    }
}
