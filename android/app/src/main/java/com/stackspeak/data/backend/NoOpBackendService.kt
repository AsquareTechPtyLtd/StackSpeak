package com.stackspeak.data.backend

import com.stackspeak.domain.ProgressSnapshot

/** Null-object backend for when no Supabase config is present (local-only build). */
class NoOpBackendService : BackendService {
    override val isConfigured: Boolean = false
    override suspend fun ensureSession(): BackendUserId = throw BackendError.NotConfigured
    override suspend fun signUpWithEmail(email: String, password: String): EmailSignUpResult = throw BackendError.NotConfigured
    override suspend fun signInWithEmail(email: String, password: String): BackendUserId = throw BackendError.NotConfigured
    override suspend fun sendPasswordReset(email: String) = throw BackendError.NotConfigured
    override suspend fun signInWithGoogle(present: WebAuthPresenter): BackendUserId = throw BackendError.NotConfigured
    override suspend fun fetchSnapshot(): ProgressSnapshot? = throw BackendError.NotConfigured
    override suspend fun pushSnapshot(snapshot: ProgressSnapshot) = throw BackendError.NotConfigured
    override suspend fun signOut() {}
}
