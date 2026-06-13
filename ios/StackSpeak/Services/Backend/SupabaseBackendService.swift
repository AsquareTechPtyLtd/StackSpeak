import Foundation
import OSLog

private let logger = Logger(category: "SupabaseBackendService")

/// The one place that knows the backend is Supabase. Talks to GoTrue (auth) and
/// PostgREST over plain `URLSession` — no SDK, no SPM dependency (CLAUDE.md →
/// "Backend & Sync"). An `actor` because it caches a mutable auth session.
///
/// Endpoints are standard Supabase REST. Anonymous sign-in requires "Allow
/// anonymous sign-ins" to be enabled in the project's Auth settings.
actor SupabaseBackendService: BackendService {
    nonisolated let config: SupabaseConfig
    private let urlSession: URLSession
    private let defaults: UserDefaults

    /// In-memory access token + cached user id; the refresh token persists so a
    /// session survives relaunch. (Refresh token in UserDefaults is acceptable
    /// for an anonymous session; move to Keychain when real sign-in lands.)
    private var accessToken: String?
    private var userId: BackendUserID?

    private static let refreshTokenKey = "supabase.refreshToken"

    nonisolated var isConfigured: Bool { true }

    init(config: SupabaseConfig,
         urlSession: URLSession = .shared,
         defaults: UserDefaults = .standard) {
        self.config = config
        self.urlSession = urlSession
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
        defaults.set(refreshToken, forKey: Self.refreshTokenKey)
    }

    var cachedUserId: BackendUserID? { userId }
    var hasAccessToken: Bool { accessToken != nil }
    var storedRefreshToken: String? { defaults.string(forKey: Self.refreshTokenKey) }

    func signOut() async {
        accessToken = nil
        userId = nil
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
