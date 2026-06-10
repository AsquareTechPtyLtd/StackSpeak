import SwiftUI
import SwiftData

@main
struct StackSpeakApp: App {
    // @State, not let: an @Observable owned by the App must survive struct
    // re-creation to keep the observation graph stable.
    @State private var bootstrap = AppBootstrap()
    @State private var themeManager = ThemeManager()

    init() {
        TypographyTokens.assertCustomFontsLoaded()
    }

    var body: some Scene {
        WindowGroup {
            if let error = bootstrap.initError {
                ErrorView(error: error) {
                    bootstrap.resetAndRetry()
                }
                .withTheme(themeManager)
            } else if let container = bootstrap.container, let services = bootstrap.services {
                ContentView()
                    .modelContainer(container)
                    .withTheme(themeManager)
                    .environment(\.services, services)
                    .task {
                        await bootstrap.initialize(themeManager: themeManager)
                    }
            } else {
                ProgressView()
                    .withTheme(themeManager)
            }
        }
    }
}
