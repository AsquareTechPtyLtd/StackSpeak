package com.stackspeak.data.backend

import com.stackspeak.domain.ProgressSnapshot
import com.stackspeak.domain.SnapshotJson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.add
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

/**
 * The only type that knows the backend is Supabase. Talks GoTrue (auth) +
 * PostgREST (progress) over OkHttp — no Supabase SDK, mirroring iOS
 * `SupabaseBackendService`. Refresh token persists via [TokenStore]; the access
 * token stays in memory. The synced record is the platform-neutral [ProgressSnapshot].
 */
class SupabaseBackendService(
    private val config: BackendConfig,
    private val tokens: TokenStore,
    private val http: OkHttpClient = OkHttpClient(),
    private val nowMillis: () -> Long = { System.currentTimeMillis() },
) : BackendService {

    private val jsonMedia = "application/json".toMediaType()
    private val lenient = Json { ignoreUnknownKeys = true }

    private var accessToken: String? = null
    private var accessExpiresAtMillis: Long = 0
    private var cachedUserId: BackendUserId? = null

    override val isConfigured: Boolean get() = config.isConfigured

    override suspend fun ensureSession(): BackendUserId {
        cachedUserId?.let { if (nowMillis() < accessExpiresAtMillis) return it }
        val refresh = tokens.refreshToken ?: throw BackendError.NotAuthenticated
        return refreshSession(refresh)
    }

    override suspend fun signInWithEmail(email: String, password: String): BackendUserId =
        authToken("password", buildJsonObject { put("email", email); put("password", password) })

    override suspend fun signUpWithEmail(email: String, password: String): EmailSignUpResult = withContext(Dispatchers.IO) {
        val body = buildJsonObject { put("email", email); put("password", password) }
        val json = postJson("${config.url}/auth/v1/signup", body, authed = false)
        if (json["access_token"]?.jsonPrimitive?.contentOrNull != null) {
            EmailSignUpResult.SignedIn(storeSession(json))
        } else {
            EmailSignUpResult.ConfirmationRequired
        }
    }

    override suspend fun sendPasswordReset(email: String) {
        withContext(Dispatchers.IO) {
            postJson("${config.url}/auth/v1/recover", buildJsonObject { put("email", email) }, authed = false)
        }
    }

    override suspend fun signInWithGoogle(present: WebAuthPresenter): BackendUserId {
        val verifier = Pkce.codeVerifier()
        val authorizeUrl = "${config.url}/auth/v1/authorize?provider=google" +
            "&redirect_to=$REDIRECT_URI&code_challenge=${Pkce.codeChallenge(verifier)}&code_challenge_method=s256"
        val callback = present.authenticate(authorizeUrl, CALLBACK_SCHEME)
        val code = extractCode(callback) ?: throw BackendError.Message("Sign-in was cancelled or returned no code.")
        return authToken("pkce", buildJsonObject { put("auth_code", code); put("code_verifier", verifier) })
    }

    override suspend fun fetchSnapshot(): ProgressSnapshot? = withContext(Dispatchers.IO) {
        val uid = ensureSession()
        val req = authedGet("${config.url}/rest/v1/progress?user_id=eq.$uid&select=data")
        val body = execute(req)
        val rows = lenient.parseToJsonElement(body).jsonArray
        val data = rows.firstOrNull()?.jsonObject?.get("data") ?: return@withContext null
        SnapshotJson.decodeFromJsonElement(ProgressSnapshot.serializer(), data)
    }

    override suspend fun pushSnapshot(snapshot: ProgressSnapshot) {
        withContext(Dispatchers.IO) {
            val uid = ensureSession()
            val payload = buildJsonArray {
                add(buildJsonObject {
                    put("user_id", uid)
                    put("schema_version", snapshot.schemaVersion)
                    put("data", SnapshotJson.encodeToJsonElement(ProgressSnapshot.serializer(), snapshot))
                })
            }
            val req = Request.Builder()
                .url("${config.url}/rest/v1/progress")
                .addHeader("apikey", config.anonKey)
                .addHeader("Authorization", "Bearer ${accessToken ?: config.anonKey}")
                .addHeader("Prefer", "resolution=merge-duplicates")
                .post(payload.toString().toRequestBody(jsonMedia))
                .build()
            execute(req)
        }
    }

    override suspend fun signOut() {
        withContext(Dispatchers.IO) {
            runCatching {
                val req = Request.Builder().url("${config.url}/auth/v1/logout")
                    .addHeader("apikey", config.anonKey)
                    .addHeader("Authorization", "Bearer ${accessToken ?: config.anonKey}")
                    .post(ByteArray(0).toRequestBody()).build()
                http.newCall(req).execute().close()
            }
            accessToken = null; cachedUserId = null; accessExpiresAtMillis = 0
            tokens.clear()
        }
    }

    // MARK: - Internals

    private suspend fun authToken(grant: String, body: JsonObject): BackendUserId = withContext(Dispatchers.IO) {
        storeSession(postJson("${config.url}/auth/v1/token?grant_type=$grant", body, authed = false))
    }

    private suspend fun refreshSession(refresh: String): BackendUserId = withContext(Dispatchers.IO) {
        val req = Request.Builder()
            .url("${config.url}/auth/v1/token?grant_type=refresh_token")
            .addHeader("apikey", config.anonKey)
            .post(buildJsonObject { put("refresh_token", refresh) }.toString().toRequestBody(jsonMedia))
            .build()
        http.newCall(req).execute().use { resp ->
            when {
                resp.isSuccessful -> storeSession(lenient.parseToJsonElement(resp.body?.string().orEmpty()).jsonObject)
                resp.code in intArrayOf(400, 401, 403) -> {
                    tokens.clear()
                    throw BackendError.SessionExpired
                }
                else -> throw BackendError.Http(resp.code)
            }
        }
    }

    private fun postJson(url: String, body: JsonObject, authed: Boolean): JsonObject {
        val builder = Request.Builder().url(url)
            .addHeader("apikey", config.anonKey)
            .post(body.toString().toRequestBody(jsonMedia))
        if (authed) builder.addHeader("Authorization", "Bearer ${accessToken ?: config.anonKey}")
        return lenient.parseToJsonElement(execute(builder.build())).jsonObject
    }

    private fun authedGet(url: String): Request = Request.Builder().url(url)
        .addHeader("apikey", config.anonKey)
        .addHeader("Authorization", "Bearer ${accessToken ?: config.anonKey}")
        .get().build()

    private fun execute(req: Request): String {
        try {
            http.newCall(req).execute().use { resp ->
                val text = resp.body?.string().orEmpty()
                if (resp.isSuccessful) return text
                // Surface a GoTrue/PostgREST error message when present.
                val msg = runCatching { lenient.parseToJsonElement(text).jsonObject }.getOrNull()
                    ?.let { it["msg"] ?: it["message"] ?: it["error_description"] }
                    ?.jsonPrimitive?.contentOrNull
                throw if (msg != null) BackendError.Message(msg) else BackendError.Http(resp.code)
            }
        } catch (e: BackendError) {
            throw e
        } catch (e: Exception) {
            throw BackendError.Transport
        }
    }

    private fun storeSession(json: JsonObject): BackendUserId {
        val access = json["access_token"]?.jsonPrimitive?.contentOrNull ?: throw BackendError.Decoding
        val userId = json["user"]?.jsonObject?.get("id")?.jsonPrimitive?.contentOrNull ?: throw BackendError.Decoding
        val expiresIn = json["expires_in"]?.jsonPrimitive?.intOrNull ?: 3600
        json["refresh_token"]?.jsonPrimitive?.contentOrNull?.let { tokens.refreshToken = it }
        accessToken = access
        accessExpiresAtMillis = nowMillis() + (expiresIn - 60) * 1000L // refresh a minute early
        cachedUserId = userId
        tokens.accountLinked = true
        return userId
    }

    private fun extractCode(callbackUrl: String): String? {
        val afterScheme = callbackUrl.substringAfter("://", "")
        val query = afterScheme.substringAfter('?', "").substringBefore('#')
        val fragment = afterScheme.substringAfter('#', "")
        return (query + "&" + fragment).split('&')
            .firstOrNull { it.startsWith("code=") }?.substringAfter("code=")?.takeIf { it.isNotBlank() }
    }

    private companion object {
        const val CALLBACK_SCHEME = "stackspeak"
        const val REDIRECT_URI = "stackspeak://auth-callback"
    }
}
