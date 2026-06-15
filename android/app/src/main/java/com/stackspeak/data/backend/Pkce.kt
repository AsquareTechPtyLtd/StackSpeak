package com.stackspeak.data.backend

import android.util.Base64
import java.security.MessageDigest
import java.security.SecureRandom

/**
 * PKCE (RFC 7636) for the Supabase web-OAuth flow (Google) — Kotlin port of iOS
 * `PKCE`. Verifier generated on-device, its SHA-256 challenge travels in the
 * authorize URL. Fails closed if the RNG errors (no zero-entropy verifier).
 */
object Pkce {
    private const val URLSAFE_NOWRAP = Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP

    /** 48 random bytes → 64 URL-safe chars (RFC 7636 permits 43–128). */
    fun codeVerifier(): String {
        val bytes = ByteArray(48)
        SecureRandom().nextBytes(bytes)
        require(bytes.any { it.toInt() != 0 }) { "RNG produced zero-entropy verifier" }
        return Base64.encodeToString(bytes, URLSAFE_NOWRAP)
    }

    /** S256 challenge: base64url(SHA-256(verifier)), no padding. */
    fun codeChallenge(verifier: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(digest, URLSAFE_NOWRAP)
    }
}
