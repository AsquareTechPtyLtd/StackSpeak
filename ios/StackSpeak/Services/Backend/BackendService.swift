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

    /// Fetches the user's remote snapshot, or nil if they have none yet.
    func fetchSnapshot() async throws -> ProgressSnapshot?

    /// Writes (upserts) the user's snapshot.
    func pushSnapshot(_ snapshot: ProgressSnapshot) async throws

    /// Forgets the local session (sign-out). Does not delete remote data.
    func signOut() async
}

/// Opaque backend user identifier (a Supabase `auth.users.id` today).
typealias BackendUserID = String

enum BackendError: Error, Equatable {
    /// No backend configured — caller should fall back to local-only behaviour.
    case notConfigured
    /// No valid session; sign in first.
    case notAuthenticated
    /// Transport/HTTP failure with the status code, when available.
    case http(status: Int)
    /// Response could not be decoded into the expected shape.
    case decoding
    /// Anything else (URLSession error, etc.).
    case transport
}
