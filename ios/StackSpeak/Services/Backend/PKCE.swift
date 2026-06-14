import Foundation
import CryptoKit

/// PKCE (RFC 7636) helpers for the Supabase web OAuth flow (Google sign-in).
/// The verifier is generated on-device, its SHA-256 challenge travels in the
/// authorize URL, and the verifier is later exchanged for a session — so an
/// intercepted authorization code is useless without it. CryptoKit is an Apple
/// framework (no SPM dependency — CLAUDE.md → "Backend & Sync").
enum PKCE {
    /// A high-entropy code verifier: 48 random bytes → 64 URL-safe chars
    /// (RFC 7636 permits 43–128). Throws if the system RNG fails rather than
    /// returning a zero-entropy verifier (RFC 7636 §7.1) — the caller surfaces
    /// a retryable sign-in error.
    static func codeVerifier() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 48)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw BackendError.transport
        }
        return base64URL(Data(bytes))
    }

    /// The S256 challenge: `base64url(SHA256(verifier))`, no padding.
    static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URL(Data(digest))
    }

    /// Base64 with the URL-safe alphabet and no `=` padding, per RFC 7636.
    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
