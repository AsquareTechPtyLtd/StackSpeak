import Foundation
import StoreKit

extension Product {
    /// "$2.99 / month" — price from StoreKit, period suffix localized here.
    var paywallPriceText: String {
        let suffix: String
        switch subscription?.subscriptionPeriod.unit {
        case .month: suffix = String(localized: "pro.gate.period.month")
        case .year:  suffix = String(localized: "pro.gate.period.year")
        default:     suffix = ""
        }
        return displayPrice + suffix
    }

    /// "7 days free" derived from the product's free-trial intro offer, so the
    /// paywall copy always matches what App Store Connect is configured to charge.
    var paywallTrialText: String? {
        guard let offer = subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let days: Int
        switch offer.period.unit {
        case .day:  days = offer.period.value
        case .week: days = offer.period.value * 7
        default:    return String(localized: "pro.gate.trial.generic")
        }
        return String(format: String(localized: "pro.gate.trial.days.format"), days)
    }
}
