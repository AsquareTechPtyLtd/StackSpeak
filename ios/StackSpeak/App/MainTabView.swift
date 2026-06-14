import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.userProgress) private var userProgress
    @State private var router = TabRouter()

    // Restrict the query to today's row only — there is never a need to load
    // every historical DailySet row in this view.
    @Query private var todaysSets: [DailySet]

    init() {
        let todayString = DailySet.todayString()
        _todaysSets = Query(filter: #Predicate<DailySet> { $0.dayString == todayString })
    }

    private var todayBadge: Int {
        guard let progress = userProgress,
              let set = todaysSets.first,
              !set.wordIds.isEmpty else { return 0 }
        return set.wordIds.filter { !progress.wordsPracticedIds.contains($0) }.count
    }

    private var reviewBadge: Int {
        guard let progress = userProgress else { return 0 }
        // Use the O(N+M) batched path rather than canAttemptAssessment(for:) per word,
        // which is O(N·M) on every body eval (each call linearly scans assessmentResults).
        return progress.attemptableAssessmentCount()
    }

    /// `.sidebarAdaptable`: tab bar on iPhone; on iPad the iOS 18 top tab bar
    /// that can morph into a sidebar.
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
        .tabViewStyle(.sidebarAdaptable)
        .environment(\.tabRouter, router)
    }
}
