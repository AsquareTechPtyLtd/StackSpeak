import Foundation

/// Fallback used when no backend is configured (no `Supabase.plist`, or a free
/// user with no cross-platform sync). Reports unconfigured and no-ops every
/// call, so the rest of the app can depend on `BackendService` unconditionally
/// without branching on "is sync available".
struct NoOpBackendService: BackendService {
    var isConfigured: Bool { false }

    func ensureSession() async throws -> BackendUserID {
        throw BackendError.notConfigured
    }

    func signInWithApple(idToken: String, rawNonce: String) async throws -> BackendUserID {
        throw BackendError.notConfigured
    }

    func signUpWithEmail(_ email: String, password: String) async throws -> EmailSignUpResult {
        throw BackendError.notConfigured
    }

    func signInWithEmail(_ email: String, password: String) async throws -> BackendUserID {
        throw BackendError.notConfigured
    }

    func sendPasswordReset(email: String) async throws {
        throw BackendError.notConfigured
    }

    func fetchSnapshot() async throws -> ProgressSnapshot? {
        throw BackendError.notConfigured
    }

    func pushSnapshot(_ snapshot: ProgressSnapshot) async throws {
        throw BackendError.notConfigured
    }

    func signOut() async {}
}
