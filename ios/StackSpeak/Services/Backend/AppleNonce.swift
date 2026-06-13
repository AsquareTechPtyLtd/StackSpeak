import Foundation
import CryptoKit

/// Nonce helpers for Sign in with Apple. Apple signs a SHA-256 *hash* of the
/// nonce into its ID token; the raw nonce is then sent to Supabase, which
/// re-hashes and compares — this binds the token to our request and blocks
/// replay. (CryptoKit is an Apple framework — no SPM dependency.)
enum AppleNonce {
    /// A cryptographically-random raw nonce to set aside and pass to Supabase.
    static func random(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            guard status == errSecSuccess else { continue }
            for byte in bytes where remaining > 0 {
                if Int(byte) < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    /// SHA-256 hex of the raw nonce — this is what we set on the Apple request.
    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
