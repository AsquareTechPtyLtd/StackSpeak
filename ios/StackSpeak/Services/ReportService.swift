import Foundation
import SwiftData
import OSLog

protocol ReportServiceProtocol: Sendable {
    func submitReport(
        wordId: UUID,
        wordTerm: String,
        stack: String,
        reason: WordReportReason,
        additionalNotes: String,
        userLevel: Int,
        modelContext: ModelContext
    ) async throws

    func getReports(modelContext: ModelContext) async throws -> [WordReport]
}

final class ReportService: ReportServiceProtocol {
    private let logger = Logger(subsystem: "com.stackspeak.ios", category: "ReportService")

    func submitReport(
        wordId: UUID,
        wordTerm: String,
        stack: String,
        reason: WordReportReason,
        additionalNotes: String = "",
        userLevel: Int,
        modelContext: ModelContext
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
            logger.info("Report submitted: \(wordTerm) - \(reason.rawValue)")

            // Future: Send to analytics or backend API
            // await sendToBackend(report)
        } catch {
            logger.error("Failed to save report: \(error.localizedDescription)")
            throw error
        }
    }

    func getReports(modelContext: ModelContext) async throws -> [WordReport] {
        let descriptor = FetchDescriptor<WordReport>(
            sortBy: [SortDescriptor(\.reportedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    // Future: Send reports to backend
    // private func sendToBackend(_ report: WordReport) async {
    //     // Implementation for sending to analytics/backend
    // }
}
