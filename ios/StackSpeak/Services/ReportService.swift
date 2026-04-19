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
    ) throws

    func getReports() throws -> [WordReport]
}

@MainActor
final class ReportService: ReportServiceProtocol {
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.stackspeak.ios", category: "ReportService")

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
    ) throws {
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
            logger.info("Report submitted reason=\(reason.rawValue, privacy: .public)")
        } catch {
            logger.error("Failed to save report: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func getReports() throws -> [WordReport] {
        let descriptor = FetchDescriptor<WordReport>(
            sortBy: [SortDescriptor(\.reportedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
}
