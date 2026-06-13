import Foundation
import SwiftData
import OSLog

private let logger = Logger(category: "SyncCoordinator")

/// Drives Pro-gated cross-platform progress sync: pull remote → additive-merge
/// with local → apply locally → push the merged result. A no-op unless a
/// backend is configured AND the user is Pro (`isProActive`). Free users keep
/// device-local progress + the platform's own backup (iCloud / Android).
///
/// Talks only to `BackendService` (never Supabase directly) and owns the
/// SwiftData write-back (see `SyncCoordinator+Apply`).
@MainActor
final class SyncCoordinator {
    private let backend: any BackendService
    let modelContext: ModelContext

    init(backend: any BackendService, modelContext: ModelContext) {
        self.backend = backend
        self.modelContext = modelContext
    }

    /// One full sync cycle. Safe to call on every foreground; cheap and silent
    /// when ineligible. Never throws — failures are logged and retried next time.
    func syncIfEligible(now: Date = Date()) async {
        guard backend.isConfigured else { return }
        guard let progress = fetchProgress(), progress.isProActive else { return }

        do {
            _ = try await backend.ensureSession()
            let local = progress.makeSnapshot(bookProgress: fetchBookProgress(), now: now)
            let remote = try await backend.fetchSnapshot()

            let merged = remote.map { ProgressSnapshot.merge(local: local, remote: $0) } ?? local

            // Only write back / push when the merge actually changed something
            // relative to local — avoids needless churn when already in sync.
            if remote != nil {
                applySnapshot(merged, to: progress)
                try modelContext.save()
            }
            var outgoing = merged
            outgoing.updatedAt = now
            try await backend.pushSnapshot(outgoing)
            logger.info("Progress sync complete")
        } catch {
            logger.error("Progress sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Fetch helpers

    func fetchProgress() -> UserProgress? {
        try? modelContext.fetch(FetchDescriptor<UserProgress>()).first
    }

    func fetchBookProgress() -> [BookProgress] {
        (try? modelContext.fetch(FetchDescriptor<BookProgress>())) ?? []
    }
}
