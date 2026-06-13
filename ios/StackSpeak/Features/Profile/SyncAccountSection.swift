import SwiftUI
import AuthenticationServices

/// Profile "Sync" section. Cross-device sync is a Pro feature; a Pro user signs
/// in with Apple so the same account links all their devices. The raw nonce is
/// generated per request and passed to Supabase to bind the Apple token.
struct SyncAccountSection: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.userProgress) private var userProgress

    @AppStorage("syncAccountLinked") private var linked = false
    @State private var rawNonce = ""
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var showEmailAuth = false

    private var isPro: Bool { userProgress?.isProActive ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            if !isPro {
                Text("profile.sync.proOnly")
                    .font(TypographyTokens.subheadline)
                    .foregroundColor(theme.colors.inkMuted)
            } else if linked {
                Label("profile.sync.signedIn", systemImage: "checkmark.icloud.fill")
                    .font(TypographyTokens.subheadline)
                    .foregroundColor(theme.colors.good)
            } else {
                Text("profile.sync.description")
                    .font(TypographyTokens.subheadline)
                    .foregroundColor(theme.colors.inkMuted)

                SignInWithAppleButton(.signIn) { request in
                    rawNonce = AppleNonce.random()
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleNonce.sha256(rawNonce)
                } onCompletion: { result in
                    handle(result)
                }
                .signInWithAppleButtonStyle(theme.systemColorScheme == .dark ? .white : .black)
                .frame(height: 44)
                .clipShape(.rect(cornerRadius: RadiusTokens.card))
                .disabled(isWorking)

                Button { showEmailAuth = true } label: {
                    Text("profile.sync.email")
                        .font(TypographyTokens.subheadline.weight(.medium))
                        .foregroundColor(theme.colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacing.sm)
                }
                .buttonStyle(.plain)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.bad)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView()
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = String(localized: "profile.sync.error.token")
                return
            }
            signIn(idToken: idToken)
        case .failure(let error):
            // Swallow the user simply cancelling the sheet.
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func signIn(idToken: String) {
        guard let services else { return }
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                _ = try await services.backend.signInWithApple(idToken: idToken, rawNonce: rawNonce)
                linked = true
                // Push local progress up to the now-linked account immediately.
                await SyncCoordinator(backend: services.backend, modelContext: modelContext)
                    .syncIfEligible()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
