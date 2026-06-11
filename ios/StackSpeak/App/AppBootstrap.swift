import SwiftUI
import SwiftData
import OSLog
import UserNotifications

private let logger = Logger(category: "App")

/// Owns the SwiftData container + services and the one-time launch initialization.
/// Held as `@State` by the app so a store failure isn't terminal: the user can
/// trigger a confirmed local reset (`resetAndRetry`) that wipes the store and
/// rebuilds, rather than being stranded on a dead-end error screen.
@MainActor
@Observable
final class AppBootstrap {
    private(set) var container: ModelContainer?
    private(set) var services: Services?
    private(set) var initError: Error?

    private static let schema = Schema([
        Word.self,
        DailySet.self,
        UserProgress.self,
        PracticedSentence.self,
        ReviewState.self,
        AssessmentResult.self,
        WordReport.self,
        BookProgress.self,
        BookmarkedCard.self
    ])

    init() {
        build()
    }

    private func build() {
        do {
            let container = try Self.makeContainer(schema: Self.schema)
            self.container = container
            self.services = Services(modelContext: container.mainContext)
            self.initError = nil
        } catch {
            logger.error("ModelContainer init failed: \(error.localizedDescription, privacy: .public)")
            self.container = nil
            self.services = nil
            self.initError = error
        }
    }

    /// User-confirmed recovery for an unrecoverable store (e.g. an incompatible
    /// schema after an app update). Wipes the local store and rebuilds. Word data
    /// reloads from the bundle on next init; user progress is lost — but this is a
    /// deliberate, confirmed action, not the silent wipe-and-retry it replaces.
    func resetAndRetry() {
        Self.deleteStoreFiles()
        build()
    }

    private static func makeContainer(schema: Schema) throws -> ModelContainer {
        // Ensure the Application Support directory exists before SwiftData tries to use it
        if let swiftDataDir = storeDirectory() {
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

    /// The directory SwiftData stores its files in (Application Support/<bundle id>).
    private static func storeDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let bundleId = Bundle.main.bundleIdentifier else { return nil }
        return appSupport.appendingPathComponent(bundleId)
    }

    /// Removes the SwiftData store files so the next container build starts clean.
    private static func deleteStoreFiles() {
        guard let dir = storeDirectory() else { return }
        // SwiftData's default store is `default.store` plus its WAL/SHM sidecars.
        for name in ["default.store", "default.store-wal", "default.store-shm"] {
            let url = dir.appendingPathComponent(name)
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
            } catch {
                logger.error("Failed to delete store file \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @MainActor
    func initialize(themeManager: ThemeManager) async {
        guard let container = container else { return }
        let context = container.mainContext

        // Check if StackRegistry loaded successfully
        if StackRegistry.shared.allStacks.isEmpty, let registryError = StackRegistry.shared.loadError {
            logger.error("StackRegistry failed to load, cannot initialize app: \(registryError.localizedDescription, privacy: .public)")
            return
        }

        do {
            let descriptor = FetchDescriptor<UserProgress>()
            if let progress = try context.fetch(descriptor).first {
                themeManager.preference = progress.themePreference

                // Rebuild the progress caches on launch in case they were lost or corrupted
                // (e.g. the credited-for-level cache was added after some results existed).
                if progress.wordsCreditedForLevelIds.isEmpty && !progress.assessmentResults.isEmpty {
                    progress.rebuildProgressCaches()
                    try context.save()
                }

                // Heal stack selection for non-Pro users: a lapsed Pro who had
                // deselected mandatory stacks would otherwise get no daily coverage
                // from them. `effectiveSelectedStacks` also guards this at read time;
                // persisting here keeps the stored selection honest too.
                if !progress.isProActive {
                    let mandatory = Set(WordStack.mandatoryStacks(for: progress.level).map(\.rawValue))
                    if !mandatory.isSubset(of: progress.selectedStacks) {
                        progress.selectedStacks = progress.selectedStacks.union(mandatory)
                        try context.save()
                    }
                }

                // Reconcile pending notifications with the stored settings so the OS
                // schedule never drifts from the database (e.g. after an in-app
                // schedule failed and left a partial/empty pending set).
                await reconcileNotifications(for: progress)
            } else if try context.fetchCount(descriptor) == 0 {
                let newProgress = UserProgress()
                context.insert(newProgress)
                try context.save()
            }
        } catch {
            logger.error("UserProgress load failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        if let services = services {
            // Reconcile the Pro entitlement before anything reads `isProActive`
            // (renewals while the app was closed extend the stored expiry).
            services.purchase.startTransactionListener()
            await services.purchase.refreshEntitlement()

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

    /// Re-schedules notifications from the stored settings when enabled and
    /// authorized, so the OS pending set matches what the DB claims.
    private func reconcileNotifications(for progress: UserProgress) async {
        guard progress.notificationEnabled else { return }
        let status = await NotificationService.shared.checkAuthorizationStatus()
        guard status == .authorized, let primary = progress.notificationTime else { return }
        do {
            try await NotificationService.shared.rescheduleNotifications(
                primary: primary,
                secondary: progress.secondReminderEnabled ? progress.secondReminderTime : nil
            )
        } catch {
            logger.error("Notification reconciliation failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
