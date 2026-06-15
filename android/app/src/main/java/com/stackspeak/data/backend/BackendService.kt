package com.stackspeak.data.backend

import com.stackspeak.domain.ProgressSnapshot

/** Opaque backend user id (a Supabase auth.users.id). */
typealias BackendUserId = String

/** Outcome of an email sign-up: a live session, or "confirm your email first". */
sealed interface EmailSignUpResult {
    data class SignedIn(val userId: BackendUserId) : EmailSignUpResult
    data object ConfirmationRequired : EmailSignUpResult
}

/** Errors surfaced by the backend seam — mirrors iOS `BackendError`. */
sealed class BackendError(message: String) : Exception(message) {
    data object NotConfigured : BackendError("Sync isn't available right now.")
    data object NotAuthenticated : BackendError("Please sign in to sync.")
    /** Refresh token permanently revoked — caller clears the link + prompts re-auth. */
    data object SessionExpired : BackendError("Your session has expired. Please sign in again.")
    data class Http(val status: Int) : BackendError("HTTP $status")
    data class Message(val text: String) : BackendError(text)
    data object Decoding : BackendError("Couldn't read the server response.")
    data object Transport : BackendError("Something went wrong. Please try again.")
}

/**
 * The single seam between the app and any sync backend — mirrors iOS
 * `BackendService`. Only [SupabaseBackendService] knows it's Supabase; everything
 * else (SyncCoordinator, UI) talks to this. No anonymous sessions: `ensureSession`
 * resumes a real one or throws.
 */
interface BackendService {
    /** Whether a backend is configured at all (URL + anon key present). */
    val isConfigured: Boolean

    /** Resumes the signed-in session (cached token, else refresh); throws if none. */
    suspend fun ensureSession(): BackendUserId

    suspend fun signUpWithEmail(email: String, password: String): EmailSignUpResult
    suspend fun signInWithEmail(email: String, password: String): BackendUserId
    suspend fun sendPasswordReset(email: String)

    /** Signs in via a provider web-OAuth flow (Google) using PKCE; [present] runs the system browser. */
    suspend fun signInWithGoogle(present: WebAuthPresenter): BackendUserId

    suspend fun fetchSnapshot(): ProgressSnapshot?
    suspend fun pushSnapshot(snapshot: ProgressSnapshot)
    suspend fun signOut()
}

/** Runs a provider web-OAuth flow (Chrome Custom Tabs) and returns the redirect URL. */
fun interface WebAuthPresenter {
    suspend fun authenticate(url: String, callbackScheme: String): String
}
