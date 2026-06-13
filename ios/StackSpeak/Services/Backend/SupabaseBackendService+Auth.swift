import Foundation

// GoTrue auth — split out per the <TypeName>+<Concern>.swift convention.
// Anonymous-first: a user gets a session with no email/password, upgradeable to
// Sign in with Apple / Google later. Requires "Allow anonymous sign-ins" in the
// project's Auth settings.
extension SupabaseBackendService {
    /// Decoded GoTrue session response (`/auth/v1/signup`, `/auth/v1/token`).
    private struct AuthResponse: Decodable {
        let access_token: String
        let refresh_token: String
        let user: AuthUser
        struct AuthUser: Decodable { let id: String }
    }

    func ensureSession() async throws -> BackendUserID {
        // Already have a live access token this launch.
        if hasAccessToken, let uid = cachedUserId { return uid }
        // Resume a persisted session by refreshing.
        if let refreshToken = storedRefreshToken {
            if let uid = try? await refresh(refreshToken: refreshToken) { return uid }
        }
        // Otherwise start a fresh anonymous session.
        return try await signInAnonymously()
    }

    // MARK: - Email / password

    func signUpWithEmail(_ email: String, password: String) async throws -> EmailSignUpResult {
        struct Body: Encodable { let email: String; let password: String }
        var request = restRequest(path: "/auth/v1/signup", query: nil)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encode(Body(email: email, password: password))
        let (data, response) = try await send(request)
        try Self.checkREST(data, response)
        // When email confirmation is required, signup returns the user but no
        // session — surface that instead of pretending they're signed in.
        struct Maybe: Decodable {
            let access_token: String?; let refresh_token: String?
            let user: User?; struct User: Decodable { let id: String }
        }
        let r = try Self.decode(Maybe.self, from: data)
        if let at = r.access_token, let rt = r.refresh_token, let uid = r.user?.id {
            setSession(accessToken: at, refreshToken: rt, userId: uid)
            return .signedIn(uid)
        }
        return .confirmationRequired
    }

    func signInWithEmail(_ email: String, password: String) async throws -> BackendUserID {
        struct Body: Encodable { let email: String; let password: String }
        var request = restRequest(path: "/auth/v1/token", query: "grant_type=password")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encode(Body(email: email, password: password))
        let (data, response) = try await send(request)
        try Self.checkREST(data, response)
        return try apply(authData: data)
    }

    func sendPasswordReset(email: String) async throws {
        struct Body: Encodable { let email: String }
        var request = restRequest(path: "/auth/v1/recover", query: nil)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encode(Body(email: email))
        let (data, response) = try await send(request)
        try Self.checkREST(data, response)
    }

    /// Like `check`, but on failure surfaces GoTrue's human message
    /// (e.g. "Invalid login credentials", "Email not confirmed").
    private static func checkREST(_ data: Data, _ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw BackendError.transport }
        guard !(200..<300).contains(http.statusCode) else { return }
        struct GoTrueError: Decodable {
            let msg: String?; let error_description: String?; let error: String?
        }
        if let e = try? JSONDecoder().decode(GoTrueError.self, from: data),
           let text = e.msg ?? e.error_description ?? e.error {
            throw BackendError.message(text)
        }
        throw BackendError.http(status: http.statusCode)
    }

    func signInWithApple(idToken: String, rawNonce: String) async throws -> BackendUserID {
        struct Body: Encodable { let provider = "apple"; let id_token: String; let nonce: String }
        var request = restRequest(path: "/auth/v1/token", query: "grant_type=id_token")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encode(Body(id_token: idToken, nonce: rawNonce))
        let (data, response) = try await send(request)
        try Self.check(response)
        return try apply(authData: data)
    }

    private func signInAnonymously() async throws -> BackendUserID {
        var request = restRequest(path: "/auth/v1/signup", query: nil)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)   // anonymous: no credentials
        let (data, response) = try await send(request)
        try Self.check(response)
        return try apply(authData: data)
    }

    private func refresh(refreshToken: String) async throws -> BackendUserID {
        var request = restRequest(path: "/auth/v1/token", query: "grant_type=refresh_token")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encode(["refresh_token": refreshToken])
        let (data, response) = try await send(request)
        try Self.check(response)
        return try apply(authData: data)
    }

    private func apply(authData: Data) throws -> BackendUserID {
        let auth = try Self.decode(AuthResponse.self, from: authData)
        setSession(accessToken: auth.access_token,
                   refreshToken: auth.refresh_token,
                   userId: auth.user.id)
        return auth.user.id
    }
}
