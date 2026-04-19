import Foundation
import SwiftData

enum WordReportReason: String, Codable, CaseIterable {
    case tooSimple = "too_simple"
    case tooComplex = "too_complex"
    case wrongMeaning = "wrong_meaning"
    case other = "other"

    var displayName: String {
        switch self {
        case .tooSimple:
            return String(localized: "report.reason.tooSimple")
        case .tooComplex:
            return String(localized: "report.reason.tooComplex")
        case .wrongMeaning:
            return String(localized: "report.reason.wrongMeaning")
        case .other:
            return String(localized: "report.reason.other")
        }
    }

    var icon: String {
        switch self {
        case .tooSimple:
            return "arrow.down.circle"
        case .tooComplex:
            return "arrow.up.circle"
        case .wrongMeaning:
            return "exclamationmark.triangle"
        case .other:
            return "ellipsis.circle"
        }
    }
}

@Model
final class WordReport {
    var id: UUID
    var wordId: UUID
    var wordTerm: String
    var reason: String // Raw value of WordReportReason
    var additionalNotes: String
    var userLevel: Int
    var reportedAt: Date
    var stack: String

    init(
        id: UUID = UUID(),
        wordId: UUID,
        wordTerm: String,
        reason: WordReportReason,
        additionalNotes: String = "",
        userLevel: Int,
        stack: String
    ) {
        self.id = id
        self.wordId = wordId
        self.wordTerm = wordTerm
        self.reason = reason.rawValue
        self.additionalNotes = additionalNotes
        self.userLevel = userLevel
        self.reportedAt = Date()
        self.stack = stack
    }

    var reasonEnum: WordReportReason {
        WordReportReason(rawValue: reason) ?? .other
    }
}
