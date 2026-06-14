import Foundation
import OSLog

private let logger = Logger(category: "SupabaseBackendService")

/// The one place that knows the backend is Supabase. Talks to GoTrue (auth) and
/// PostgREST over plain `URLSession` — no SDK, no SPM dependency (CLAUDE.md →
/// "Backend & Sync"). An `actor` because it caches a mutable auth session.
///
/// Endpoints are standard Supabase REST. A session exists only after a real
/// sign-in (Sign in with Apple / email-password) — there is no anonymous
/// sign-in, so "Allow anonymous sign-ins" can stay disabled in the project.
actor SupabaseBackendService: BackendService {
    nonisolated let config: SupabaseConfig
    private let urlSession: URLSession
    private let keychain: KeychainStore
    private let defaults: UserDefaults

    /// In-memory access token + cached user id; the refresh token persists in the
    /// Keychain (a real-account credential — never UserDefaults) so a session
    /// survives relaunch without leaking into unencrypted backups.
    private var accessToken: String?
    private var userId: BackendUserID?

    private static let refreshTokenKey = "supabase.refreshToken"

    nonisolated var isConfigured: Bool { true }

    init(config: SupabaseConfig,
         urlSession: URLSession = .shared,
         keychain: KeychainStore = KeychainStore(),
         defaults: UserDefaults = .standard) {
        self.config = config
        self.urlSession = urlSession
        self.keychain = keychain
        self.defaults = defaults
    }

    // MARK: - Progress (PostgREST)

    func fetchSnapshot() async throws -> ProgressSnapshot? {
        let uid = try await ensureSession()
        var request = restRequest(path: "/rest/v1/progress",
                                  query: "user_id=eq.\(uid)&select=data")
        request.httpMethod = "GET"
        let (data, response) = try await send(request)
        try Self.check(response)
        // PostgREST returns an array of rows; we want the single row's `data`.
        struct Row: Decodable { let data: ProgressSnapshot }
        let rows = try Self.decode([Row].self, from: data)
        return rows.first?.data
    }

    func pushSnapshot(_ snapshot: ProgressSnapshot) async throws {
        let uid = try await ensureSession()
        struct Row: Encodable {
            let user_id: String
            let data: ProgressSnapshot
            let schema_version: Int
        }
        let body = [Row(user_id: uid, data: snapshot, schema_version: snapshot.schemaVersion)]
        var request = restRequest(path: "/rest/v1/progress", query: nil)
        request.httpMethod = "POST"
        // Upsert on the primary key (user_id).
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encode(body)
        let (_, response) = try await send(request)
        try Self.check(response)
    }

    // MARK: - Request building / sending

    /// A PostgREST/auth request pre-stamped with the apikey and (when present)
    /// the bearer access token.
    // intentionally internal: shared with the +Auth extension in a separate file.
    func restRequest(path: String, query: String?) -> URLRequest {
        var components = URLComponents(url: config.url.appendingPathComponent(path),
                                       resolvingAgainstBaseURL: false)
        components?.percentEncodedQuery = query
        var request = URLRequest(url: components?.url ?? config.url.appendingPathComponent(path))
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // intentionally internal: shared with the +Auth extension in a separate file.
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch {
            logger.error("Request failed: \(error.localizedDescription, privacy: .public)")
            throw BackendError.transport
        }
    }

    // MARK: - Session storage (used by +Auth)

    func setSession(accessToken: String, refreshToken: String, userId: String) {
        self.accessToken = accessToken
        self.userId = userId
        keychain.set(refreshToken, for: Self.refreshTokenKey)
        // Drop any legacy plaintext copy from before the Keychain migration.
        defaults.removeObject(forKey: Self.refreshTokenKey)
    }

    var cachedUserId: BackendUserID? { userId }
    var hasAccessToken: Bool { accessToken != nil }

    /// Reads the persisted refresh token, transparently migrating a legacy
    /// UserDefaults token into the Keychain on first access (so existing
    /// sessions survive the upgrade without forcing a re-login).
    var storedRefreshToken: String? {
        if let token = keychain.get(Self.refreshTokenKey) { return token }
        guard let legacy = defaults.string(forKey: Self.refreshTokenKey) else { return nil }
        keychain.set(legacy, for: Self.refreshTokenKey)
        defaults.removeObject(forKey: Self.refreshTokenKey)
        return legacy
    }

    func signOut() async {
        accessToken = nil
        userId = nil
        keychain.delete(Self.refreshTokenKey)
        defaults.removeObject(forKey: Self.refreshTokenKey)
    }

    /// Clears only the stored credentials (called after a permanent refresh
    /// rejection so the UI can prompt re-auth). Does NOT call the GoTrue logout
    /// endpoint — the token was already rejected server-side.
    func clearStoredSession() {
        accessToken = nil
        userId = nil
        keychain.delete(Self.refreshTokenKey)
        defaults.removeObject(forKey: Self.refreshTokenKey)
    }

    // MARK: - Helpers

    static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw BackendError.transport }
        guard (200..<300).contains(http.statusCode) else {
            throw BackendError.http(status: http.statusCode)
        }
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do { return try encoder.encode(value) } catch { throw BackendError.decoding }
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do { return try decoder.decode(type, from: data) } catch { throw BackendError.decoding }
    }
}
