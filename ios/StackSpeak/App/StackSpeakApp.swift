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

        let schema = Schema([
            Word.self,
            DailySet.self,
            UserProgress.self,
            PracticedSentence.self,
            ReviewState.self,
            AssessmentResult.self,
            WordReport.self
        ])

        do {
            container = try Self.makeContainer(schema: schema)
        } catch let firstError {
            // Schema migration failed (e.g. after an app update added new model types).
            // Wipe the store and retry so the app stays usable. Word data reloads from
            // the bundle; user progress is lost, but a crash loop is worse.
            logger.error("ModelContainer init failed, wiping store and retrying: \(firstError.localizedDescription, privacy: .public)")
            Self.deleteStoreFiles(schema: schema)
            do {
                container = try Self.makeContainer(schema: schema)
            } catch let secondError {
                logger.error("ModelContainer retry failed: \(secondError.localizedDescription, privacy: .public)")
                error = secondError
            }
        }

        self.modelContainer = container
        self.initError = error
        self.services = container.map { Services(modelContext: $0.mainContext) }

        TypographyTokens.assertCustomFontsLoaded()
    }

    private static func makeContainer(schema: Schema) throws -> ModelContainer {
        // Ensure the Application Support directory exists before SwiftData tries to use it
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
           let bundleId = Bundle.main.bundleIdentifier {
            let swiftDataDir = appSupport.appendingPathComponent(bundleId)
            do {
                try FileManager.default.createDirectory(at: swiftDataDir, withIntermediateDirectories: true)
                logger.info("Ensured SwiftData directory exists at \(swiftDataDir.path, privacy: .public)")
            } catch {
                logger.error("Failed to create SwiftData directory: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Explicitly disable CloudKit sync. The app's entitlements include CloudKit
        // (used by CloudKitReportService for word reports), and without `cloudKitDatabase: .none`
        // SwiftData auto-enables CloudKit sync, which fails because our models use
        // `@Attribute(.unique)` and non-optional relationships — both unsupported with CloudKit.
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])

        // Exclude from iCloud/iTunes backups — progress is device-local by design.
        if let storeURL = container.configurations.first?.url {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var url = storeURL
            try? url.setResourceValues(values)
        }

        return container
    }

    private static func deleteStoreFiles(schema: Schema) {
        // Delete the entire SwiftData directory for this app to ensure a clean slate.
        // SwiftData stores files in Application Support/{bundle-id}/
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        // SwiftData uses the bundle identifier as a subdirectory
        if let bundleId = Bundle.main.bundleIdentifier {
            let swiftDataDir = appSupport.appendingPathComponent(bundleId)
            do {
                try FileManager.default.removeItem(at: swiftDataDir)
                logger.info("Deleted SwiftData directory at \(swiftDataDir.path, privacy: .public)")
            } catch {
                logger.error("Failed to delete SwiftData directory: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            // Fallback: try to delete the default.store files directly
            let storeBase = appSupport.appendingPathComponent("default.store")
            for suffix in ["", "-wal", "-shm"] {
                let url = URL(fileURLWithPath: storeBase.path + suffix)
                try? FileManager.default.removeItem(at: url)
            }
        }
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

        // Check if StackRegistry loaded successfully
        if StackRegistry.shared.allStacks.isEmpty, let registryError = StackRegistry.shared.loadError {
            logger.error("StackRegistry failed to load, cannot initialize app: \(registryError.localizedDescription, privacy: .public)")
            return
        }

        let descriptor = FetchDescriptor<UserProgress>()
        let progress = try? context.fetch(descriptor).first

        if let progress {
            themeManager.preference = progress.themePreference
            themeManager.density = progress.densityPreference

            // Rebuild the two-correct cache on launch in case it was lost or corrupted.
            if progress.wordsWithTwoCorrectIds.isEmpty && !progress.assessmentResults.isEmpty {
                progress.rebuildTwoCorrectCache()
                do { try context.save() } catch { logger.error("Cache rebuild save failed: \(error.localizedDescription, privacy: .public)") }
            }
        } else {
            // Race-safe singleton check: only insert if count is truly zero
            let count = (try? context.fetchCount(descriptor)) ?? 0
            if count == 0 {
                let newProgress = UserProgress()
                context.insert(newProgress)
                do { try context.save() } catch { logger.error("UserProgress init save failed: \(error.localizedDescription, privacy: .public)") }
            } else {
                logger.warning("UserProgress creation skipped - already exists (race avoided)")
            }
        }

        if let services = services {
            do {
                try await services.word.loadWordsFromBundle()
                // Update catalog status after successful load
                let totalCount = try context.fetchCount(FetchDescriptor<Word>())
                services.catalogStatus = .loaded(count: totalCount)
            } catch {
                logger.error("Word bundle load failed: \(error.localizedDescription, privacy: .public)")
            }
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

                Text("Force-quit this app and relaunch to try again.")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
                    .multilineTextAlignment(.center)
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
    @Environment(\.userProgress) private var userProgress
    @Query private var dailySets: [DailySet]

    private var todayBadge: Int {
        guard let progress = userProgress else { return 0 }
        let todayString = DailySet.todayString()
        guard let set = dailySets.first(where: { $0.dayString == todayString }),
              !set.wordIds.isEmpty else { return 0 }
        return set.wordIds.filter { !progress.wordsPracticedIds.contains($0) }.count
    }

    private var reviewBadge: Int {
        guard let progress = userProgress else { return 0 }
        return progress.wordsEligibleForAssessment()
            .filter { progress.canAttemptAssessment(for: $0) }.count
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("home.tab", systemImage: "house.fill") }
                .badge(todayBadge)

            ReviewView()
                .tabItem { Label("review.tab", systemImage: "brain.fill") }
                .badge(reviewBadge)

            LibraryView()
                .tabItem { Label("library.tab", systemImage: "books.vertical.fill") }

            ProfileView()
                .tabItem { Label("profile.tab", systemImage: "person.fill") }
        }
    }
}
