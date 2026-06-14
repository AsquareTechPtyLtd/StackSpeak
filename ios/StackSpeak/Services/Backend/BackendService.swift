import Foundation

/// The single seam between the app and *any* sync backend.
///
/// Nothing outside `SupabaseBackendService` may know the backend is Supabase —
/// ViewModels and the sync layer talk only to this protocol. Switching backends
/// (or self-hosting) later means writing one new conformer, nothing else.
/// See CLAUDE.md → "Backend & Sync".
protocol BackendService: Sendable {
    /// Whether a backend is configured at all (anon key + URL present). When
    /// false the app runs fully local — no sign-in, no sync.
    var isConfigured: Bool { get }

    /// Resumes the signed-in user's session (from the cached token, else by
    /// refreshing the stored one) and returns its id. There is no anonymous
    /// fallback — throws `.notAuthenticated` if the user has not signed in.
    /// Cheap to call repeatedly — reuses the cached session when valid.
    @discardableResult
    func ensureSession() async throws -> BackendUserID

    /// Signs in with an Apple ID token (native Sign in with Apple), establishing
    /// the Apple-linked session so the same Apple ID resolves to the same user
    /// across devices — the basis of cross-device sync. `rawNonce` is the
    /// un-hashed nonce that was hashed onto the request.
    @discardableResult
    func signInWithApple(idToken: String, rawNonce: String) async throws -> BackendUserID

    /// Signs in through a provider's web OAuth flow (Google) using PKCE. The
    /// `present` seam runs the system web-auth sheet and returns the callback
    /// URL; all OAuth/PKCE specifics stay inside the backend so nothing leaks to
    /// the UI. Establishes the provider-linked session, like `signInWithApple`.
    @discardableResult
    func signInWithGoogle(present: any WebAuthPresenting) async throws -> BackendUserID

    /// Creates an email/password account. Returns `.signedIn` when a session is
    /// issued immediately, or `.confirmationRequired` when the project requires
    /// the user to confirm via an emailed link before first sign-in.
    func signUpWithEmail(_ email: String, password: String) async throws -> EmailSignUpResult

    /// Signs into an existing email/password account, replacing the current session.
    @discardableResult
    func signInWithEmail(_ email: String, password: String) async throws -> BackendUserID

    /// Sends a password-reset email.
    func sendPasswordReset(email: String) async throws

    /// Fetches the user's remote snapshot, or nil if they have none yet.
    func fetchSnapshot() async throws -> ProgressSnapshot?

    /// Writes (upserts) the user's snapshot.
    func pushSnapshot(_ snapshot: ProgressSnapshot) async throws

    /// Forgets the local session (sign-out). Does not delete remote data.
    func signOut() async
}

/// Presents a provider's web OAuth flow and returns the final callback URL.
/// Implemented in the app layer (it wraps `ASWebAuthenticationSession`, which
/// needs a window anchor); injected into the backend so AuthenticationServices /
/// UIKit never leak into `SupabaseBackendService`.
protocol WebAuthPresenting: Sendable {
    /// Opens `url` in a system web-auth sheet and resolves with the redirect URL
    /// once the provider calls back to `callbackScheme://…`. Throws on
    /// user-cancel (`ASWebAuthenticationSessionError.canceledLogin`) or failure.
    func authenticate(url: URL, callbackScheme: String) async throws -> URL
}

/// Opaque backend user identifier (a Supabase `auth.users.id` today).
typealias BackendUserID = String

/// Outcome of an email sign-up: either a live session, or "go confirm your email".
enum EmailSignUpResult: Equatable {
    case signedIn(BackendUserID)
    case confirmationRequired
}

enum BackendError: Error, Equatable {
    /// No backend configured — caller should fall back to local-only behaviour.
    case notConfigured
    /// No valid session; sign in first.
    case notAuthenticated
    /// The stored session was permanently revoked (HTTP 400/401/403 on refresh).
    /// Callers should clear the linked-account flag and prompt re-auth; the
    /// Keychain token has already been wiped by the time this is thrown.
    case sessionExpired
    /// Transport/HTTP failure with the status code, when available.
    case http(status: Int)
    /// A server-provided message (e.g. "Invalid login credentials").
    case message(String)
    /// Response could not be decoded into the expected shape.
    case decoding
    /// Anything else (URLSession error, etc.).
    case transport

    var localizedDescription: String {
        switch self {
        case .message(let text): return text
        case .notConfigured: return String(localized: "sync.error.notConfigured")
        case .notAuthenticated: return String(localized: "sync.error.notAuthenticated")
        case .sessionExpired: return String(localized: "sync.error.sessionExpired")
        default: return String(localized: "sync.error.generic")
        }
    }
}

// Conform to LocalizedError so `(error as Error).localizedDescription` — the form
// used in catch blocks — surfaces our message instead of the generic NSError
// bridge. Without this, `BackendError.message("…")` would display as
// "The operation couldn't be completed…".
extension BackendError: LocalizedError {
    var errorDescription: String? { localizedDescription }
}
