import SwiftUI
import UIKit
import UserNotifications

// Notification prompt/banner concern for HomeView — split out per the
// <TypeName>+<Concern>.swift convention to keep the primary file under the
// size limit. Stored properties + body remain in HomeView.swift.
extension HomeView {
    @ViewBuilder
    var notificationAlertButtons: some View {
        Button("notifications.prompt.enable") {
            Task { _ = try? await services?.notification.requestAuthorization() }
        }
        Button("notifications.prompt.notNow", role: .cancel) { }
    }

    var notificationBanner: some View {
        HStack(spacing: theme.spacing.md) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                HStack(spacing: theme.spacing.xs) {
                    Image(systemName: "bell.fill")
                        .foregroundColor(theme.colors.accent)
                    Text("notifications.banner.title")
                        .font(TypographyTokens.headline)
                        .foregroundColor(theme.colors.ink)
                }
                Text("notifications.banner.message")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
            }
            Spacer()
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("notifications.banner.enable")
                    .font(TypographyTokens.callout.weight(.semibold))
                    .foregroundColor(theme.colors.accent)
            }
            Button(action: { showNotificationBanner = false }) {
                Image(systemName: "xmark")
                    .font(.system(.caption))
                    .foregroundColor(theme.colors.inkFaint)
            }
        }
        .padding(theme.spacing.cardPadding)
        .background(theme.colors.accentBg)
        .clipShape(.rect(cornerRadius: RadiusTokens.card))
    }

    func submit(wordId: UUID, explanation: String, method: InputMethod, markAsMastered: Bool, progress: UserProgress) {
        guard let services else { return }
        let firstEverPractice = progress.wordsPracticedIds.isEmpty
        viewModel.submitExplanation(
            for: wordId,
            explanation: explanation,
            inputMethod: method,
            markAsMastered: markAsMastered,
            services: services,
            userProgress: progress
        )
        if firstEverPractice && !progress.notificationEnabled {
            showNotificationPrompt = true
        }
    }

    func checkNotificationStatus() async {
        guard let services else { return }
        notificationAuthStatus = await services.notification.checkAuthorizationStatus()
        if notificationAuthStatus == .denied, let progress = userProgress, !progress.wordsPracticedIds.isEmpty {
            showNotificationBanner = true
        }
    }
}
