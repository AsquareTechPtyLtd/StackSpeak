import SwiftUI

/// Email/password sign-in & sign-up sheet for cross-device sync. Talks only to
/// `BackendService`; on success it links the account, pushes local progress up,
/// and dismisses. Handles the email-confirmation case gracefully whether or not
/// the Supabase project requires it.
struct EmailAuthView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext

    @AppStorage(SyncDefaults.accountLinkedKey) private var linked = false

    private enum Mode: Hashable { case signIn, signUp }
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !isWorking
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                Picker("email.auth.mode", selection: $mode) {
                    Text("email.auth.signIn").tag(Mode.signIn)
                    Text("email.auth.signUp").tag(Mode.signUp)
                }
                .pickerStyle(.segmented)

                VStack(spacing: theme.spacing.sm) {
                    TextField("email.auth.email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Divider().overlay(theme.colors.line)
                    SecureField("email.auth.password", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                }
                .padding(theme.spacing.md)
                .cardChrome()

                if let infoMessage {
                    Text(infoMessage).font(TypographyTokens.footnote).foregroundColor(theme.colors.good)
                }
                if let errorMessage {
                    Text(errorMessage).font(TypographyTokens.footnote).foregroundColor(theme.colors.bad)
                }

                PrimaryCTAButton(mode == .signIn ? "email.auth.signIn" : "email.auth.signUp",
                                 isLoading: isWorking) { submit() }
                    .disabled(!canSubmit)

                if mode == .signIn {
                    Button("email.auth.forgot") { resetPassword() }
                        .font(TypographyTokens.footnote.weight(.medium))
                        .foregroundColor(theme.colors.accent)
                        .disabled(!email.contains("@") || isWorking)
                }

                Spacer()
            }
            .padding(theme.spacing.xl)
            .background(theme.colors.bg.ignoresSafeArea())
            .navigationTitle("email.auth.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        guard let services else { return }
        isWorking = true; errorMessage = nil; infoMessage = nil
        Task {
            defer { isWorking = false }
            do {
                switch mode {
                case .signIn:
                    _ = try await services.backend.signInWithEmail(email, password: password)
                    await finishLinked()
                case .signUp:
                    let result = try await services.backend.signUpWithEmail(email, password: password)
                    switch result {
                    case .signedIn: await finishLinked()
                    case .confirmationRequired:
                        infoMessage = String(localized: "email.auth.confirmSent")
                        mode = .signIn
                    }
                }
            } catch let error as BackendError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func finishLinked() async {
        guard let services else { return }
        linked = true
        await SyncCoordinator(backend: services.backend, modelContext: modelContext).syncIfEligible()
        dismiss()
    }

    private func resetPassword() {
        guard let services else { return }
        isWorking = true; errorMessage = nil; infoMessage = nil
        Task {
            defer { isWorking = false }
            do {
                try await services.backend.sendPasswordReset(email: email)
                infoMessage = String(localized: "email.auth.resetSent")
            } catch let error as BackendError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
