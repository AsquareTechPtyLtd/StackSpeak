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

    /// Ensures there is a signed-in user (anonymous to start) and returns its id.
    /// Cheap to call repeatedly — reuses the cached session when valid.
    @discardableResult
    func ensureSession() async throws -> BackendUserID

    /// Signs in with an Apple ID token (native Sign in with Apple). Replaces the
    /// current (anonymous) session with the Apple-linked user, so the same Apple
    /// ID resolves to the same user across devices — the basis of cross-device
    /// sync. `rawNonce` is the un-hashed nonce that was hashed onto the request.
    @discardableResult
    func signInWithApple(idToken: String, rawNonce: String) async throws -> BackendUserID

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
        default: return String(localized: "sync.error.generic")
        }
    }
}
