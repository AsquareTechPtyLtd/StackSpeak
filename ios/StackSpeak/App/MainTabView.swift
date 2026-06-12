import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.userProgress) private var userProgress
    @Query private var dailySets: [DailySet]
    @State private var router = TabRouter()

    private var todayBadge: Int {
        guard let progress = userProgress else { return 0 }
        let todayString = DailySet.todayString()
        guard let set = dailySets.first(where: { $0.dayString == todayString }),
              !set.wordIds.isEmpty else { return 0 }
        return set.wordIds.filter { !progress.wordsPracticedIds.contains($0) }.count
    }

    private var reviewBadge: Int {
        guard let progress = userProgress else { return 0 }
        return progress.wordsEligibleForAssessment
            .filter { progress.canAttemptAssessment(for: $0) }.count
    }

    /// Standard iOS tab bar on both iPhone and iPad. Uses .tabBarOnly style
    /// because the destination views aren't wired through a NavigationSplitView.
    /// Future: .sidebarAdaptable + split-view scaffolding for iPad.
    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selection) {
            Tab("home.tab", systemImage: "house.fill", value: TabRouter.Tab.home) {
                HomeView()
            }
            .badge(todayBadge)

            Tab("review.tab", systemImage: "brain.fill", value: TabRouter.Tab.review) {
                ReviewView()
            }
            .badge(reviewBadge)

            Tab("books.tab", systemImage: "books.vertical.fill", value: TabRouter.Tab.books) {
                BooksTabView()
            }

            Tab("profile.tab", systemImage: "person.fill", value: TabRouter.Tab.profile) {
                ProfileView()
            }
        }
        .environment(\.tabRouter, router)
    }
}
