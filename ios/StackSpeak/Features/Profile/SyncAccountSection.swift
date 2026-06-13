import SwiftUI
import AuthenticationServices

/// Profile "Sync" section. Identity (sign-in) and entitlement (Pro) are
/// independent: sign-in is always offered so a returning user can link an
/// account and restore progress without re-buying. The *sync execution* stays
/// Pro-gated (see `SyncCoordinator.syncIfEligible`) — a signed-in non-Pro user
/// just has an account; pull/push doesn't run until Pro is active.
///
/// The raw nonce is generated per request and passed to Supabase to bind the
/// Apple token.
struct SyncAccountSection: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.userProgress) private var userProgress

    @AppStorage(SyncDefaults.accountLinkedKey) private var linked = false
    @AppStorage(SyncDefaults.lastSyncedAtKey) private var lastSyncedAt = 0.0
    @State private var rawNonce = ""
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isWorking = false
    @State private var showEmailAuth = false
    @State private var showProSheet = false

    private var isPro: Bool { userProgress?.isProActive ?? false }

    /// Relative "last synced" string ("2 minutes ago"), or nil before the first
    /// successful sync (0 = never).
    private var lastSynced: String? {
        guard lastSyncedAt > 0 else { return nil }
        return Date(timeIntervalSince1970: lastSyncedAt)
            .formatted(.relative(presentation: .named))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            if linked {
                signedInState
            } else {
                signedOutState
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkMuted)
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
        .sheet(isPresented: $showProSheet) {
            ProGateSheet()
        }
    }

    // MARK: - States

    @ViewBuilder
    private var signedInState: some View {
        if isPro {
            Label("profile.sync.signedIn", systemImage: "checkmark.icloud.fill")
                .font(TypographyTokens.subheadline)
                .foregroundColor(theme.colors.good)
            if let lastSynced {
                Text(String(format: String(localized: "profile.sync.lastSynced.format"), lastSynced))
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkMuted)
            }
        } else {
            Text("profile.sync.signedInNotPro")
                .font(TypographyTokens.subheadline)
                .foregroundColor(theme.colors.inkMuted)
            getProButton
        }
        signOutButton
    }

    @ViewBuilder
    private var signedOutState: some View {
        Text("profile.sync.description")
            .font(TypographyTokens.subheadline)
            .foregroundColor(theme.colors.inkMuted)

        SignInWithAppleButton(.signIn) { request in
            rawNonce = AppleNonce.random()
            // Only the identity token (JWT) is needed for the GoTrue id_token grant.
            // Requesting fullName/email is unnecessary and exposes extra user data.
            request.requestedScopes = []
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
        .disabled(isWorking)

        Text("profile.sync.returning")
            .font(TypographyTokens.caption)
            .foregroundColor(theme.colors.inkMuted)
        restoreButton
    }

    // MARK: - Buttons

    private var restoreButton: some View {
        Button { restore() } label: {
            Text("profile.sync.restore")
                .font(TypographyTokens.subheadline.weight(.medium))
                .foregroundColor(theme.colors.accent)
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
    }

    private var getProButton: some View {
        Button { showProSheet = true } label: {
            Text("profile.sync.getPro")
                .font(TypographyTokens.subheadline.weight(.semibold))
                .foregroundColor(theme.colors.accent)
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
    }

    private var signOutButton: some View {
        Button(role: .destructive) { signOut() } label: {
            Text("profile.sync.signOut")
                .font(TypographyTokens.subheadline.weight(.medium))
                .foregroundColor(theme.colors.bad)
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
    }

    // MARK: - Actions

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

    private func signOut() {
        guard let services else { return }
        isWorking = true
        statusMessage = nil
        Task {
            defer { isWorking = false }
            await services.backend.signOut()
            linked = false   // stops sync; local progress stays on device
        }
    }

    private func signIn(idToken: String) {
        guard let services else { return }
        isWorking = true
        errorMessage = nil
        statusMessage = nil
        Task {
            defer { isWorking = false }
            do {
                _ = try await services.backend.signInWithApple(idToken: idToken, rawNonce: rawNonce)
                linked = true
                // Push local progress up to the now-linked account immediately.
                // No-ops until Pro is active (gated inside the coordinator).
                await SyncCoordinator(backend: services.backend, modelContext: modelContext)
                    .syncIfEligible()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restore() {
        guard let services else { return }
        isWorking = true
        errorMessage = nil
        statusMessage = nil
        Task {
            defer { isWorking = false }
            do {
                let restored = try await services.purchase.restorePurchases()
                statusMessage = String(localized: restored
                    ? "profile.sync.restore.done"
                    : "profile.sync.restore.none")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview("SyncAccountSection — Light") {
    SyncAccountSection()
        .padding()
        .withTheme(ThemeManager())
}

#Preview("SyncAccountSection — Dark") {
    SyncAccountSection()
        .padding()
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
