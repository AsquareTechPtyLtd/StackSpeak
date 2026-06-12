import SwiftUI

/// Programmatic tab selection for the root `TabView`. Injected as an optional
/// environment value so views presented outside the tab scaffold (previews,
/// onboarding) can read it safely and no-op.
@Observable
final class TabRouter {
    enum Tab: Hashable {
        case home
        case review
        case books
        case profile
    }

    var selection: Tab = .home
}

private struct TabRouterKey: EnvironmentKey {
    static let defaultValue: TabRouter? = nil
}

extension EnvironmentValues {
    var tabRouter: TabRouter? {
        get { self[TabRouterKey.self] }
        set { self[TabRouterKey.self] = newValue }
    }
}
