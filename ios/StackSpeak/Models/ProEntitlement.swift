import Foundation

/// Pure rules for mapping App Store subscription state onto `UserProgress`.
/// Lives in production code so `PurchaseService` and its unit tests assert
/// against the same logic (same pattern as `StackSelectionPolicy`).
enum ProEntitlement {
    static let monthlyProductId = "com.stackspeak.ios.pro.monthly"
    static let yearlyProductId = "com.stackspeak.ios.pro.yearly"
    static let lifetimeProductId = "com.stackspeak.ios.pro.lifetime"

    /// Auto-renewing subscriptions — these carry an expiry.
    static let subscriptionProductIds: Set<String> = [monthlyProductId, yearlyProductId]
    /// One-time non-consumable that grants Pro permanently (no expiry).
    static let lifetimeProductIds: Set<String> = [lifetimeProductId]

    /// All product IDs that grant Pro.
    static let productIds: Set<String> = subscriptionProductIds.union(lifetimeProductIds)

    /// Whether `productID` is the one-time lifetime purchase rather than a subscription.
    static func isLifetime(_ productID: String) -> Bool {
        lifetimeProductIds.contains(productID)
    }

    /// The expiry to persist given the latest verified transaction expiries.
    /// Returns nil when there is nothing to apply.
    static func latestExpiry(from expirations: [Date]) -> Date? {
        expirations.max()
    }

    /// Applies a verified subscription expiry to the user's progress record.
    ///
    /// Grant-or-extend only: a nil expiry or one earlier than what's already
    /// stored never downgrades. Lapsing is handled naturally by
    /// `UserProgress.isProActive` comparing the stored expiry against now, and
    /// never revoking here keeps manually granted entitlements (the DEBUG dev
    /// toggle) intact across launches.
    ///
    /// - Returns: true when the progress record was modified.
    @discardableResult
    static func apply(expiry: Date?, to progress: UserProgress) -> Bool {
        guard let expiry else { return false }
        if let existing = progress.proExpiryDate, existing >= expiry, progress.isPro {
            return false
        }
        progress.isPro = true
        progress.proExpiryDate = max(progress.proExpiryDate ?? .distantPast, expiry)
        return true
    }

    /// Grants permanent Pro from a verified lifetime (non-consumable) purchase.
    /// Sets the lifetime flag, which `isProActive` honours regardless of any
    /// subscription expiry. Idempotent — never downgrades.
    ///
    /// - Returns: true when the progress record was modified.
    @discardableResult
    static func applyLifetime(to progress: UserProgress) -> Bool {
        guard !progress.isLifetimePro else { return false }
        progress.isLifetimePro = true
        progress.isPro = true
        return true
    }
}
