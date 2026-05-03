import Foundation
import SwiftData
import OSLog

@MainActor
protocol ReportServiceProtocol {
    func submitReport(
        wordId: UUID,
        wordTerm: String,
        stack: String,
        reason: WordReportReason,
        additionalNotes: String,
        userLevel: Int
    ) async throws

    func getReports() throws -> [WordReport]
}

@MainActor
final class ReportService: ReportServiceProtocol {
    private let modelContext: ModelContext
    private let logger = Logger(category: "ReportService")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func submitReport(
        wordId: UUID,
        wordTerm: String,
        stack: String,
        reason: WordReportReason,
        additionalNotes: String = "",
        userLevel: Int
    ) async throws {
        let report = WordReport(
            wordId: wordId,
            wordTerm: wordTerm,
            reason: reason,
            additionalNotes: additionalNotes,
            userLevel: userLevel,
            stack: stack
        )

        modelContext.insert(report)

        do {
            try modelContext.save()
            logger.info("Report saved locally reason=\(reason.rawValue, privacy: .public)")
        } catch {
            logger.error("Failed to save report: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        // Capture scalars before leaving @MainActor — WordReport is not Sendable.
        let reportedAt = report.reportedAt
        let reasonRaw = report.reason
        let notes = report.additionalNotes
        let level = report.userLevel

        Task.detached(priority: .background) {
            await CloudKitReportService.shared.upload(
                wordId: wordId,
                wordTerm: wordTerm,
                stack: stack,
                reason: reasonRaw,
                additionalNotes: notes,
                userLevel: level,
                reportedAt: reportedAt
            )
        }
    }

    func getReports() throws -> [WordReport] {
        let descriptor = FetchDescriptor<WordReport>(
            sortBy: [SortDescriptor(\.reportedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
}
