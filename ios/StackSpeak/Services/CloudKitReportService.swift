import CloudKit
import OSLog

/// Uploads word reports to the CloudKit public database so the developer can
/// review them via the CloudKit Dashboard (console.developer.apple.com).
///
/// Failures are non-fatal — the report is always saved locally first.
final class CloudKitReportService: Sendable {
    static let shared = CloudKitReportService()
    private init() {}

    private let database = CKContainer(identifier: "iCloud.com.stackspeak.ios").publicCloudDatabase
    private let logger = Logger(subsystem: "com.stackspeak.ios", category: "CloudKitReportService")

    func upload(
        wordId: UUID,
        wordTerm: String,
        stack: String,
        reason: String,
        additionalNotes: String,
        userLevel: Int,
        reportedAt: Date
    ) async {
        let record = CKRecord(recordType: "WordReport")
        record["wordId"] = wordId.uuidString
        record["wordTerm"] = wordTerm
        record["stack"] = stack
        record["reason"] = reason
        record["additionalNotes"] = additionalNotes
        record["userLevel"] = userLevel
        record["reportedAt"] = reportedAt
        record["appVersion"] = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"

        do {
            _ = try await database.save(record)
            logger.info("Report uploaded to CloudKit")
        } catch {
            logger.error("CloudKit upload failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
