import Foundation
import SwiftData
import OSLog

private let logger = Logger(category: "SyncCoordinator")

/// Shared keys for sync state persisted in UserDefaults, so the coordinator and
/// the SwiftUI views (via @AppStorage) agree on the same flag.
enum SyncDefaults {
    /// True once the user has signed in with a real account (Apple/email).
    static let accountLinkedKey = "syncAccountLinked"

    /// Unix time (seconds) of the last successful sync cycle. 0 = never synced.
    static let lastSyncedAtKey = "syncLastSyncedAt"

    static var isAccountLinked: Bool {
        UserDefaults.standard.bool(forKey: accountLinkedKey)
    }
}

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
    // `internal` (no modifier) because SyncCoordinator+Apply.swift is a separate
    // file: Swift only allows `private` members to be accessed from same-file
    // extensions, so `private` here would break the cross-file Apply extension.
    let modelContext: ModelContext

    init(backend: any BackendService, modelContext: ModelContext) {
        self.backend = backend
        self.modelContext = modelContext
    }

    /// One full sync cycle. Safe to call on every foreground; cheap and silent
    /// when ineligible. Never throws — failures are logged and retried next time.
    func syncIfEligible(now: Date = Date()) async {
        guard backend.isConfigured else { return }
        // Only sync once a real account is linked (Apple/email). Without a linked
        // account there is no session at all — ensureSession inside fetchSnapshot
        // would throw `.notAuthenticated` — so syncing is meaningless and we bail early.
        guard SyncDefaults.isAccountLinked else { return }
        guard let progress = fetchProgress(), progress.isProActive else { return }

        do {
            // Capture local state before the async gap. `ensureSession` is NOT called
            // here explicitly — fetchSnapshot() and pushSnapshot() each call it
            // internally, so a standalone call here would be redundant (3× per cycle).
            let preAwaitLocal = progress.makeSnapshot(bookProgress: fetchBookProgress(), now: now)
            let remote = try await backend.fetchSnapshot()

            // H3: After the await, re-snapshot live local state and fold it in so
            // any MainActor mutations that occurred during the network round-trip are
            // never clobbered. The result is a true superset of both.
            let postAwaitLocal = progress.makeSnapshot(bookProgress: fetchBookProgress(), now: now)
            let merged: ProgressSnapshot
            if let remote {
                // Merge pre-await local with remote, then fold in post-await local.
                let withRemote = ProgressSnapshot.merge(local: preAwaitLocal, remote: remote)
                merged = ProgressSnapshot.merge(local: withRemote, remote: postAwaitLocal)
            } else {
                merged = postAwaitLocal
            }

            // H9: Only write back and push when the merge actually changed something
            // relative to current local state — avoids needless churn and bumping
            // updatedAt when already in sync. First sync (remote == nil) always pushes
            // so a brand-new account uploads its local progress immediately.
            if let remote, merged != postAwaitLocal {
                applySnapshot(merged, to: progress)
                try modelContext.save()
            }
            if remote == nil || merged != postAwaitLocal {
                var outgoing = merged
                outgoing.updatedAt = now
                try await backend.pushSnapshot(outgoing)
                UserDefaults.standard.set(now.timeIntervalSince1970, forKey: SyncDefaults.lastSyncedAtKey)
                logger.info("Progress sync complete (pushed)")
            } else {
                logger.info("Progress sync complete (already in sync, skipped push)")
            }
        } catch BackendError.sessionExpired {
            // H4: Permanent auth rejection — the refresh token was revoked. Clear the
            // linked-account flag so the Profile UI stops showing "Synced" and can
            // prompt re-auth. The Keychain was already wiped by ensureSession/refresh.
            logger.warning("Sync session expired — clearing linked-account flag")
            UserDefaults.standard.set(false, forKey: SyncDefaults.accountLinkedKey)
        } catch BackendError.transport {
            // Transient network failure — stay silent so a momentary offline doesn't
            // unlink the account or spam the user. Will retry next foreground.
            logger.info("Sync skipped (transport error, will retry)")
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
