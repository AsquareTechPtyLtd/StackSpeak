import SwiftUI
import SwiftData
import Foundation

enum CatalogStatus: Equatable {
    case loading
    case loaded(count: Int)
}

/// Container for all app services, injected via EnvironmentValues.
/// Constructed once in StackSpeakApp and shared across the view hierarchy.
/// Services are accessed via protocol types for testability.
@MainActor
@Observable
final class Services {
    let word: any WordRepository
    let progress: any ProgressRepository
    let notification: any NotificationRepository
    let reviewScheduler: any ReviewRepository
    let speech: any SpeechRepository
    let report: any ReportServiceProtocol
    let bookCatalog: BookCatalogService
    let bookmark: any BookmarkRepository
    let purchase: any PurchaseRepository

    var catalogStatus: CatalogStatus = .loading

    init(modelContext: ModelContext) {
        self.word = WordService(modelContext: modelContext)
        self.progress = ProgressService(modelContext: modelContext)
        self.notification = NotificationService()
        self.reviewScheduler = ReviewSchedulerService(modelContext: modelContext)
        self.speech = SpeechService()
        self.report = ReportService(modelContext: modelContext)
        self.bookCatalog = BookCatalogService(source: BundledBookSource.main())
        self.bookmark = BookmarkService(modelContext: modelContext)
        self.purchase = PurchaseService(modelContext: modelContext)
    }

    // Preview/Test initializer with mock repositories
    init(
        word: any WordRepository,
        progress: any ProgressRepository,
        notification: any NotificationRepository,
        reviewScheduler: any ReviewRepository,
        speech: any SpeechRepository,
        report: any ReportServiceProtocol,
        bookCatalog: BookCatalogService,
        bookmark: any BookmarkRepository,
        purchase: any PurchaseRepository
    ) {
        self.word = word
        self.progress = progress
        self.notification = notification
        self.reviewScheduler = reviewScheduler
        self.speech = speech
        self.report = report
        self.bookCatalog = bookCatalog
        self.bookmark = bookmark
        self.purchase = purchase
    }
}

// MARK: - Environment Keys

struct ServicesKey: EnvironmentKey {
    // Sentinel default — real Services instance is injected at app root.
    static let defaultValue: Services? = nil
}

struct UserProgressKey: EnvironmentKey {
    // UserProgress is optional — nil before onboarding completes.
    static let defaultValue: UserProgress? = nil
}

// SwiftUI's `EnvironmentValues` requires Sendable types, but SwiftData's `@Model`
// macro emits only an *unavailable* Sendable marker. This explicit conformance
// satisfies the requirement for storing `UserProgress?` in the environment.
//
// **Why @unchecked Sendable is safe here:**
// UserProgress is always accessed on the MainActor via `@Environment(\.userProgress)`,
// and SwiftData enforces that model mutations happen on the model context's actor.
// The environment propagates the reference, not cross-actor copies, so no data races.
//
// **How to apply:** Only use UserProgress via `@Environment(\.userProgress)` or
// MainActor-isolated contexts. Do not pass instances across actor boundaries.
extension UserProgress: @unchecked Sendable {}


extension EnvironmentValues {
    var services: Services? {
        get { self[ServicesKey.self] }
        set { self[ServicesKey.self] = newValue }
    }

    var userProgress: UserProgress? {
        get { self[UserProgressKey.self] }
        set { self[UserProgressKey.self] = newValue }
    }
}
