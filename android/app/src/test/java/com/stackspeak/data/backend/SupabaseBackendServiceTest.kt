package com.stackspeak.data.backend

import com.stackspeak.domain.ProgressSnapshot
import com.stackspeak.domain.SnapshotJson
import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.time.Instant

/** M5: the Supabase REST layer issues the right GoTrue/PostgREST calls and parses
 *  sessions/snapshots — verified against a MockWebServer (no live Supabase needed). */
class SupabaseBackendServiceTest {

    private lateinit var server: MockWebServer
    private lateinit var tokens: InMemoryTokenStore
    private lateinit var service: SupabaseBackendService

    private fun snapshot(level: Int) = ProgressSnapshot(
        schemaVersion = 2, updatedAt = Instant.parse("2026-01-01T00:00:00Z"), level = level,
        currentStreak = 0, longestStreak = 0, didCompleteOnboarding = true,
        practicedWordIds = emptyList(), masteredWordIds = emptyList(), bookmarkedWordIds = emptyList(),
        wordsWithTwoCorrectIds = emptyList(), wordsCreditedForLevelIds = emptyList(),
        selectedStacks = listOf("api-basic"), shuffleSeed = "ABCDEF01-2345-6789-ABCD-EF0123456789",
        wordQueueCursor = 0, reviewStates = emptyList(), assessmentResults = emptyList(),
        practicedSentences = emptyList(), bookProgress = emptyList(),
    )

    @Before
    fun setUp() {
        server = MockWebServer().also { it.start() }
        tokens = InMemoryTokenStore()
        val config = BackendConfig(server.url("/").toString().removeSuffix("/"), "anon-key")
        service = SupabaseBackendService(config, tokens)
    }

    @After
    fun tearDown() = server.shutdown()

    private fun enqueueSession() = server.enqueue(
        MockResponse().setResponseCode(200).setBody(
            """{"access_token":"acc","refresh_token":"ref","expires_in":3600,"user":{"id":"user-123"}}"""
        )
    )

    @Test
    fun signInWithEmailParsesAndStoresSession() = runBlocking {
        enqueueSession()
        val uid = service.signInWithEmail("a@b.com", "pw")
        assertEquals("user-123", uid)
        assertEquals("ref", tokens.refreshToken)
        assertTrue(tokens.accountLinked)

        val req = server.takeRequest()
        assertTrue(req.path!!.contains("/auth/v1/token?grant_type=password"))
        assertEquals("anon-key", req.getHeader("apikey"))
        assertTrue(req.body.readUtf8().contains("\"email\":\"a@b.com\""))
    }

    @Test
    fun signInSurfacesServerError() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(400).setBody("""{"error_description":"Invalid login credentials"}"""))
        try {
            service.signInWithEmail("a@b.com", "wrong")
            fail("expected error")
        } catch (e: BackendError.Message) {
            assertEquals("Invalid login credentials", e.text)
        }
    }

    @Test
    fun fetchSnapshotDecodesRow() = runBlocking {
        enqueueSession()
        service.signInWithEmail("a@b.com", "pw")
        val data = SnapshotJson.encodeToString(ProgressSnapshot.serializer(), snapshot(level = 7))
        server.enqueue(MockResponse().setResponseCode(200).setBody("""[{"data":$data}]"""))

        val result = service.fetchSnapshot()
        assertEquals(7, result?.level)
        server.takeRequest() // sign-in
        val get = server.takeRequest()
        assertTrue(get.path!!.contains("/rest/v1/progress?user_id=eq.user-123"))
    }

    @Test
    fun fetchSnapshotReturnsNullWhenNoRow() = runBlocking {
        enqueueSession()
        service.signInWithEmail("a@b.com", "pw")
        server.enqueue(MockResponse().setResponseCode(200).setBody("[]"))
        assertNull(service.fetchSnapshot())
    }

    @Test
    fun pushSnapshotUpsertsWithMergeHeader() = runBlocking {
        enqueueSession()
        service.signInWithEmail("a@b.com", "pw")
        server.enqueue(MockResponse().setResponseCode(201))

        service.pushSnapshot(snapshot(level = 9))
        server.takeRequest() // sign-in
        val post = server.takeRequest()
        assertTrue(post.path!!.contains("/rest/v1/progress"))
        assertEquals("resolution=merge-duplicates", post.getHeader("Prefer"))
        val body = post.body.readUtf8()
        assertTrue(body.contains("\"user_id\":\"user-123\""))
        assertTrue(body.contains("\"schema_version\":2"))
    }

    @Test
    fun ensureSessionThrowsWhenNoToken() = runBlocking {
        try {
            service.ensureSession()
            fail("expected NotAuthenticated")
        } catch (e: BackendError.NotAuthenticated) { /* expected */ }
    }
}
