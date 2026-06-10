import Foundation
import SwiftData

@Model
final class ReviewState {
    /// SM-2 spaced-repetition algorithm tuning constants.
    private enum SM2 {
        static let initialEasiness = 2.5
        static let minEasiness = 1.3
        static let easinessIncrement = 0.1
        static let easinessQualityCoeff = 0.08
        static let easinessQualitySquaredCoeff = 0.02
        static let qualityFailThreshold = 3
        static let firstInterval = 1
        static let secondInterval = 6
    }

    var wordId: UUID
    var easinessFactor: Double
    var interval: Int
    var repetitions: Int
    var dueDate: Date
    var lastReviewedAt: Date?

    // `now`/`calendar` are injectable so interval scheduling is testable
    // without mocking system time.
    init(wordId: UUID, now: Date = Date(), calendar: Calendar = .current) {
        self.wordId = wordId
        self.easinessFactor = SM2.initialEasiness
        self.interval = SM2.firstInterval
        self.repetitions = 0
        self.dueDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        self.lastReviewedAt = nil
    }

    func updateAfterReview(quality: Int, now: Date = Date(), calendar: Calendar = .current) {
        lastReviewedAt = now

        if quality < SM2.qualityFailThreshold {
            repetitions = 0
            interval = SM2.firstInterval
        } else {
            let qDelta = Double(5 - quality)
            let efAdjustment = SM2.easinessIncrement - qDelta * (SM2.easinessQualityCoeff + qDelta * SM2.easinessQualitySquaredCoeff)
            easinessFactor = max(SM2.minEasiness, easinessFactor + efAdjustment)

            switch repetitions {
            case 0: interval = SM2.firstInterval
            case 1: interval = SM2.secondInterval
            default: interval = Int(Double(interval) * easinessFactor)
            }

            repetitions += 1
        }

        dueDate = calendar.date(byAdding: .day, value: interval, to: now) ?? now
    }
}
