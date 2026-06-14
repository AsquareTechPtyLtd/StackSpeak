import Foundation

// GoTrue auth — split out per the <TypeName>+<Concern>.swift convention.
// Account-linked only: a session exists exclusively after a real sign-in
// (Sign in with Apple / email-password). There is no anonymous session — sync
// is Pro-gated and account-linked, so a bare anonymous user would only litter
// the DB with rows that can never sync.
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
        // Resume a persisted session by refreshing the stored token.
        if let refreshToken = storedRefreshToken {
            do {
                return try await refresh(refreshToken: refreshToken)
            } catch BackendError.transport {
                // Transient failure (network/URLSession error) — keep the Keychain
                // token intact and surface it so the caller can stay silent/retry.
                throw BackendError.transport
            } catch BackendError.http(let status) where (400..<500).contains(status) {
                // Permanent HTTP rejection (400/401/403 = token revoked/not found).
                // Wipe the stale credential so the UI can prompt re-auth.
                clearStoredSession()
                throw BackendError.sessionExpired
            } catch BackendError.message {
                // GoTrue returned a structured error message on the refresh endpoint —
                // this only happens when the token is definitively invalid/revoked.
                clearStoredSession()
                throw BackendError.sessionExpired
            } catch {
                // Any other error (e.g. decoding, 5xx) — treat as transient; don't clear.
                throw error
            }
        }
        // No session and no resumable token — the user has not signed in. Callers
        // are already gated on `isAccountLinked`, so this only fires if the stored
        // session was lost; surface it rather than minting an anonymous user.
        throw BackendError.notAuthenticated
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
        try Self.checkREST(data, response)
        return try apply(authData: data)
    }

    // MARK: - Google (web OAuth, PKCE)

    /// The custom scheme + redirect registered in Supabase → Auth → URL
    /// Configuration. `ASWebAuthenticationSession` intercepts this scheme itself,
    /// so it needs no Info.plist URL-type registration (and not registering it
    /// keeps other apps from launching us on it).
    private static let googleCallbackScheme = "stackspeak"
    private static let googleRedirectURI = "stackspeak://auth-callback"

    func signInWithGoogle(present: any WebAuthPresenting) async throws -> BackendUserID {
        // PKCE: keep the verifier on-device; only its hash travels in the URL.
        let verifier = PKCE.codeVerifier()
        var components = URLComponents(
            url: config.url.appendingPathComponent("/auth/v1/authorize"),
            resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: Self.googleRedirectURI),
            URLQueryItem(name: "code_challenge", value: PKCE.codeChallenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "s256"),
        ]
        guard let authorizeURL = components?.url else { throw BackendError.transport }

        let callbackURL = try await present.authenticate(
            url: authorizeURL, callbackScheme: Self.googleCallbackScheme)

        guard let code = Self.queryValue("code", in: callbackURL) else {
            // GoTrue redirects with ?error/&error_description on denial.
            if let message = Self.queryValue("error_description", in: callbackURL)
                ?? Self.queryValue("error", in: callbackURL) {
                throw BackendError.message(message)
            }
            throw BackendError.transport
        }

        // Exchange the authorization code + verifier for a session.
        struct Body: Encodable { let auth_code: String; let code_verifier: String }
        var request = restRequest(path: "/auth/v1/token", query: "grant_type=pkce")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encode(Body(auth_code: code, code_verifier: verifier))
        let (data, response) = try await send(request)
        try Self.checkREST(data, response)
        return try apply(authData: data)
    }

    /// Reads a parameter from a redirect URL, checking both the query and the
    /// fragment (GoTrue places OAuth params in either depending on flow).
    private static func queryValue(_ name: String, in url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let value = components?.queryItems?.first(where: { $0.name == name })?.value {
            return value
        }
        guard let fragment = components?.fragment else { return nil }
        var fragmentComponents = URLComponents()
        fragmentComponents.percentEncodedQuery = fragment
        return fragmentComponents.queryItems?.first(where: { $0.name == name })?.value
    }

    private func refresh(refreshToken: String) async throws -> BackendUserID {
        var request = restRequest(path: "/auth/v1/token", query: "grant_type=refresh_token")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encode(["refresh_token": refreshToken])
        let (data, response) = try await send(request)
        try Self.checkREST(data, response)
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
