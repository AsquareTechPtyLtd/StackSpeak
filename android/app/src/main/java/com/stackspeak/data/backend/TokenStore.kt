package com.stackspeak.data.backend

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/** Supabase project config (anon key is safe to ship — RLS-protected). */
data class BackendConfig(val url: String, val anonKey: String) {
    val isConfigured: Boolean
        get() = url.startsWith("http") && anonKey.isNotBlank()
}

/**
 * Persists the Supabase refresh token + account-linked flag. The refresh token is
 * sensitive, so production uses [EncryptedTokenStore] (Android Keystore-backed) —
 * never plain SharedPreferences. Tests use an in-memory implementation.
 */
interface TokenStore {
    var refreshToken: String?
    var accountLinked: Boolean
    fun clear()
}

/** EncryptedSharedPreferences-backed store (Android Keystore master key). */
class EncryptedTokenStore(context: Context) : TokenStore {
    private val prefs = EncryptedSharedPreferences.create(
        context,
        "stackspeak_secure",
        MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
    )

    override var refreshToken: String?
        get() = prefs.getString(KEY_REFRESH, null)
        set(value) = prefs.edit().apply { if (value == null) remove(KEY_REFRESH) else putString(KEY_REFRESH, value) }.apply()

    override var accountLinked: Boolean
        get() = prefs.getBoolean(KEY_LINKED, false)
        set(value) = prefs.edit().putBoolean(KEY_LINKED, value).apply()

    override fun clear() {
        prefs.edit().clear().apply()
    }

    private companion object {
        const val KEY_REFRESH = "supabase_refresh_token"
        const val KEY_LINKED = "account_linked"
    }
}

/** In-memory store for unit tests. */
class InMemoryTokenStore(
    override var refreshToken: String? = null,
    override var accountLinked: Boolean = false,
) : TokenStore {
    override fun clear() {
        refreshToken = null
        accountLinked = false
    }
}
