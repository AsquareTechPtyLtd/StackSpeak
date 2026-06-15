package com.stackspeak.data

import com.stackspeak.data.backend.BackendError
import com.stackspeak.data.backend.BackendService
import com.stackspeak.data.backend.TokenStore
import com.stackspeak.domain.ProgressSnapshot
import com.stackspeak.domain.mergeSnapshots
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

/** Outcome of a sync attempt. */
sealed interface SyncResult {
    data object Synced : SyncResult
    data class Skipped(val reason: String) : SyncResult
    data class Failed(val error: Throwable) : SyncResult
}

/**
 * Cross-platform progress sync — ports iOS `SyncCoordinator`. Gated on three
 * conditions (configured + account linked + Pro), then pull → merge → apply →
 * push-if-changed. Failures never block offline use; a permanently-revoked token
 * clears the link.
 */
@Singleton
class SyncCoordinator @Inject constructor(
    private val backend: BackendService,
    private val progress: ProgressRepository,
    private val entitlement: EntitlementRepository,
    private val tokens: TokenStore,
) {
    /** Injectable clock for tests (Hilt provides the no-arg constructor). */
    internal var now: () -> Instant = { Instant.now() }
    suspend fun syncIfEligible(): SyncResult {
        if (!backend.isConfigured) return SyncResult.Skipped("not configured")
        if (!tokens.accountLinked) return SyncResult.Skipped("no account linked")
        if (!entitlement.isProActive()) return SyncResult.Skipped("Pro required")

        return try {
            backend.ensureSession()
            val local = progress.ensureLoaded().toSnapshot(now())
            val remote = backend.fetchSnapshot()

            if (remote == null) {
                backend.pushSnapshot(local)
            } else {
                val merged = mergeSnapshots(local, remote)
                progress.applySnapshot(merged)
                // Push only when the merge added something the remote lacks (H9:
                // pushing every cycle dirties the store + makes remote look newer).
                if (normalize(merged) != normalize(remote)) backend.pushSnapshot(merged)
            }
            SyncResult.Synced
        } catch (e: BackendError.SessionExpired) {
            tokens.clear()
            SyncResult.Skipped("session expired")
        } catch (e: BackendError.NotAuthenticated) {
            SyncResult.Skipped("not authenticated")
        } catch (e: Throwable) {
            SyncResult.Failed(e)
        }
    }

    /** Compare content ignoring the timestamp (which always differs). */
    private fun normalize(s: ProgressSnapshot): ProgressSnapshot = s.copy(updatedAt = Instant.EPOCH)
}
