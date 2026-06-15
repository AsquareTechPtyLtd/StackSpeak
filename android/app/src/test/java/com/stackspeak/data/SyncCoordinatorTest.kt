package com.stackspeak.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.stackspeak.data.backend.BackendError
import com.stackspeak.data.backend.BackendService
import com.stackspeak.data.backend.BackendUserId
import com.stackspeak.data.backend.EmailSignUpResult
import com.stackspeak.data.backend.InMemoryTokenStore
import com.stackspeak.data.backend.WebAuthPresenter
import com.stackspeak.data.local.AppDatabase
import com.stackspeak.data.local.ProgressLocalStore
import com.stackspeak.domain.ProgressSnapshot
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.Instant

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class SyncCoordinatorTest {

    private class FakeBackend(
        override val isConfigured: Boolean = true,
        var ensureError: Throwable? = null,
        var remote: ProgressSnapshot? = null,
    ) : BackendService {
        var pushed: ProgressSnapshot? = null
        override suspend fun ensureSession(): BackendUserId { ensureError?.let { throw it }; return "uid" }
        override suspend fun fetchSnapshot(): ProgressSnapshot? = remote
        override suspend fun pushSnapshot(snapshot: ProgressSnapshot) { pushed = snapshot }
        override suspend fun signUpWithEmail(email: String, password: String) = EmailSignUpResult.ConfirmationRequired
        override suspend fun signInWithEmail(email: String, password: String) = "uid"
        override suspend fun sendPasswordReset(email: String) {}
        override suspend fun signInWithGoogle(present: WebAuthPresenter) = "uid"
        override suspend fun signOut() {}
    }

    private lateinit var db: AppDatabase
    private lateinit var progress: ProgressRepository
    private lateinit var tokens: InMemoryTokenStore
    private lateinit var entitlement: EntitlementRepository

    @Before
    fun setUp() {
        val ctx = ApplicationProvider.getApplicationContext<android.content.Context>()
        db = Room.inMemoryDatabaseBuilder(ctx, AppDatabase::class.java).allowMainThreadQueries().build()
        progress = ProgressRepository(ProgressLocalStore(db.progressDao()))
        tokens = InMemoryTokenStore(refreshToken = "ref", accountLinked = true)
        entitlement = EntitlementRepository().apply { setProActive(true) }
    }

    @After
    fun tearDown() = db.close()

    private fun coordinator(backend: BackendService) =
        SyncCoordinator(backend, progress, entitlement, tokens).apply { now = { Instant.parse("2026-02-01T00:00:00Z") } }

    @Test
    fun skipsWhenNotConfigured() = runBlocking {
        val r = coordinator(FakeBackend(isConfigured = false)).syncIfEligible()
        assertTrue(r is SyncResult.Skipped)
    }

    @Test
    fun skipsWhenNotLinked() = runBlocking {
        tokens.accountLinked = false
        val r = coordinator(FakeBackend()).syncIfEligible()
        assertTrue(r is SyncResult.Skipped)
    }

    @Test
    fun skipsWhenNotPro() = runBlocking {
        entitlement.setProActive(false)
        val r = coordinator(FakeBackend()).syncIfEligible()
        assertTrue(r is SyncResult.Skipped)
    }

    @Test
    fun firstSyncPushesLocalWhenRemoteAbsent() = runBlocking {
        progress.completeOnboarding(setOf("api-basic"))
        val backend = FakeBackend(remote = null)
        val r = coordinator(backend).syncIfEligible()
        assertEquals(SyncResult.Synced, r)
        assertNotNull("local pushed", backend.pushed)
        assertTrue(backend.pushed!!.selectedStacks.contains("api-basic"))
    }

    @Test
    fun mergesRemoteIntoLocalAndPushes() = runBlocking {
        progress.completeOnboarding(setOf("api-basic"))
        progress.markMastered("AAAA1111-0000-0000-0000-000000000001")
        val remote = progress.ensureLoaded().toSnapshot(Instant.parse("2026-01-01T00:00:00Z"))
            .copy(masteredWordIds = listOf("BBBB2222-0000-0000-0000-000000000002"))
        val backend = FakeBackend(remote = remote)

        val r = coordinator(backend).syncIfEligible()
        assertEquals(SyncResult.Synced, r)
        // Local now holds the union of both devices' mastered words.
        val merged = progress.ensureLoaded().masteredWordIds
        assertTrue(merged.contains("AAAA1111-0000-0000-0000-000000000001"))
        assertTrue(merged.contains("BBBB2222-0000-0000-0000-000000000002"))
        assertNotNull("pushed because remote lacked local's word", backend.pushed)
    }

    @Test
    fun sessionExpiredClearsLinkAndSkips() = runBlocking {
        val backend = FakeBackend().apply { ensureError = BackendError.SessionExpired }
        val r = coordinator(backend).syncIfEligible()
        assertTrue(r is SyncResult.Skipped)
        assertTrue("link cleared", !tokens.accountLinked && tokens.refreshToken == null)
    }
}
