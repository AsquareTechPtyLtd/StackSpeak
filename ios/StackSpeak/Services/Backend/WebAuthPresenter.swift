import AuthenticationServices
import UIKit

/// Drives `ASWebAuthenticationSession` for a provider OAuth flow (Google).
///
/// It lives in the app rather than inside `SupabaseBackendService` because the
/// system sheet needs a UI window anchor — keeping it behind the
/// `WebAuthPresenting` seam lets the backend actor stay UIKit-free and Supabase
/// stays the only type that knows the OAuth mechanics. MainActor-isolated; a
/// `@MainActor` class is implicitly `Sendable`, satisfying the seam.
@MainActor
final class WebAuthPresenter: NSObject, WebAuthPresenting {
    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url, callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? BackendError.transport)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            if !session.start() {
                continuation.resume(throwing: BackendError.transport)
            }
        }
    }
}

extension WebAuthPresenter: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        return window ?? ASPresentationAnchor()
    }
}
