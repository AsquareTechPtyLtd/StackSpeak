import Foundation
import StoreKit

extension Product {
    /// "$2.99 / month" — price from StoreKit, period suffix localized here.
    /// A non-subscription product (the lifetime purchase) gets a one-time suffix.
    var paywallPriceText: String {
        let suffix: String
        switch subscription?.subscriptionPeriod.unit {
        case .month: suffix = String(localized: "pro.gate.period.month")
        case .year:  suffix = String(localized: "pro.gate.period.year")
        case nil:    suffix = String(localized: "pro.gate.period.lifetime")
        default:     suffix = ""
        }
        return displayPrice + suffix
    }

    /// True for the one-time lifetime purchase (no recurring subscription).
    var isLifetimePurchase: Bool { subscription == nil }

    /// Free-trial length in days from the intro offer; nil when there is no
    /// free trial or the period doesn't reduce to days (month/year units).
    var paywallTrialDays: Int? {
        guard let offer = subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        switch offer.period.unit {
        case .day:  return offer.period.value
        case .week: return offer.period.value * 7
        default:    return nil
        }
    }

    /// "7 days free" derived from the product's free-trial intro offer, so the
    /// paywall copy always matches what App Store Connect is configured to charge.
    var paywallTrialText: String? {
        guard let offer = subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        guard let days = paywallTrialDays else {
            return String(localized: "pro.gate.trial.generic")
        }
        return String(format: String(localized: "pro.gate.trial.days.format"), days)
    }
}
