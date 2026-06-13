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
        /// Maximum ± fraction the due-date offset is jittered by. Spreads cards
        /// that share an interval ladder so they don't all resurface together.
        static let intervalFuzz = 0.1
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

        // SM-2 adjusts the easiness factor on EVERY review, including lapses —
        // this is what makes the schedule adapt to a card's difficulty. The
        // update must NOT live only in the pass branch: with the Again=2 /
        // Good=4 grades this app uses, Good yields ΔEF = 0, so an EF update
        // gated on success alone never moves and every card collapses to a
        // fixed interval ladder. Applying it here lets a lapse (q<3) dock EF
        // and permanently slow a struggled card.
        let qDelta = Double(5 - quality)
        let efAdjustment = SM2.easinessIncrement - qDelta * (SM2.easinessQualityCoeff + qDelta * SM2.easinessQualitySquaredCoeff)
        // Capture EF before mutating it: SM-2 multiplies the interval by the OLD
        // easiness factor, so the update must happen after the interval is computed.
        let oldEF = easinessFactor
        easinessFactor = max(SM2.minEasiness, easinessFactor + efAdjustment)

        if quality < SM2.qualityFailThreshold {
            repetitions = 0
            interval = SM2.firstInterval
        } else {
            switch repetitions {
            case 0: interval = SM2.firstInterval
            case 1: interval = SM2.secondInterval
            default: interval = Int(Double(interval) * oldEF)
            }
            repetitions += 1
        }

        // Jitter only the scheduled due date, never the stored `interval`, so
        // the SM-2 ladder stays clean (no compounding drift) while two cards
        // sharing an interval land on different days.
        let offset = max(1, Int((Double(interval) * intervalJitter).rounded()))
        dueDate = calendar.date(byAdding: .day, value: offset, to: now) ?? now
    }

    /// Stable multiplier in `[1 - intervalFuzz, 1 + intervalFuzz]` derived from
    /// `wordId`, so the schedule stays deterministic and reproducible (no RNG)
    /// while different cards get different offsets.
    private var intervalJitter: Double {
        var hash: UInt64 = 14695981039346656037  // FNV-1a 64-bit offset basis
        withUnsafeBytes(of: wordId.uuid) { bytes in
            for byte in bytes {
                hash = (hash ^ UInt64(byte)) &* 1099511628211
            }
        }
        let fraction = Double(hash % 1000) / 999.0          // 0...1
        return (1 - SM2.intervalFuzz) + fraction * (SM2.intervalFuzz * 2)
    }
}
