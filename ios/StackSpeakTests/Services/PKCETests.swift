import Testing
import Foundation
@testable import StackSpeak

@Suite("PKCE — RFC 7636 (Google web OAuth)")
struct PKCETests {
    @Test("codeVerifier is URL-safe and within the 43–128 length bounds")
    func verifierShape() {
        let verifier = PKCE.codeVerifier()
        #expect((43...128).contains(verifier.count))
        // base64url alphabet only — never the base64 +,/ or = padding.
        #expect(!verifier.contains("+"))
        #expect(!verifier.contains("/"))
        #expect(!verifier.contains("="))
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        #expect(verifier.unicodeScalars.allSatisfy { allowed.contains($0) })
    }

    @Test("codeVerifier is random per call")
    func verifierIsRandom() {
        #expect(PKCE.codeVerifier() != PKCE.codeVerifier())
    }

    @Test("S256 challenge matches the RFC 7636 Appendix B test vector")
    func challengeKnownVector() {
        // From RFC 7636 Appendix B.
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let expected = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        #expect(PKCE.codeChallenge(for: verifier) == expected)
    }

    @Test("S256 challenge is itself URL-safe and unpadded")
    func challengeShape() {
        let challenge = PKCE.codeChallenge(for: PKCE.codeVerifier())
        #expect(!challenge.contains("+"))
        #expect(!challenge.contains("/"))
        #expect(!challenge.contains("="))
        // SHA-256 → 32 bytes → 43 base64url chars (no padding).
        #expect(challenge.count == 43)
    }
}
