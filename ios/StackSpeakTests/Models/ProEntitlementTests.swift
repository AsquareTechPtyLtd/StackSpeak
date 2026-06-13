import Testing
import Foundation
@testable import StackSpeak

@Suite("ProEntitlement — App Store → UserProgress mapping")
struct ProEntitlementTests {

    @Test("Product IDs cover the monthly, yearly, and lifetime products")
    func productIds() {
        #expect(ProEntitlement.productIds == [
            "com.stackspeak.ios.pro.monthly",
            "com.stackspeak.ios.pro.yearly",
            "com.stackspeak.ios.pro.lifetime"
        ])
        #expect(ProEntitlement.isLifetime("com.stackspeak.ios.pro.lifetime"))
        #expect(!ProEntitlement.isLifetime("com.stackspeak.ios.pro.yearly"))
    }

    @Test("Applying a lifetime purchase grants permanent Pro")
    func grantsLifetime() {
        let p = UserProgress()
        let changed = ProEntitlement.applyLifetime(to: p)
        #expect(changed == true)
        #expect(p.isLifetimePro == true)
        #expect(p.isPro == true)
        #expect(p.isProActive == true)
    }

    @Test("Lifetime Pro is active with no expiry, and even past a lapsed subscription")
    func lifetimeOutlivesSubscriptionExpiry() {
        let p = UserProgress()
        p.proExpiryDate = Date().addingTimeInterval(-60 * 60 * 24)   // lapsed sub
        ProEntitlement.applyLifetime(to: p)
        #expect(p.isProActive == true)   // honoured regardless of expiry
    }

    @Test("Granting lifetime twice is idempotent")
    func lifetimeIdempotent() {
        let p = UserProgress()
        #expect(ProEntitlement.applyLifetime(to: p) == true)
        #expect(ProEntitlement.applyLifetime(to: p) == false)
    }

    @Test("A new UserProgress is not lifetime Pro")
    func defaultsNotLifetime() {
        #expect(UserProgress().isLifetimePro == false)
    }

    @Test("latestExpiry picks the furthest-out expiry")
    func latestExpiryPicksMax() {
        let near = Date(timeIntervalSince1970: 1_700_000_000)
        let far = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(ProEntitlement.latestExpiry(from: [near, far]) == far)
        #expect(ProEntitlement.latestExpiry(from: []) == nil)
    }

    @Test("Applying a future expiry to a free user grants Pro")
    func grantsPro() {
        let p = UserProgress()
        let expiry = Date().addingTimeInterval(60 * 60 * 24 * 30)
        let changed = ProEntitlement.apply(expiry: expiry, to: p)
        #expect(changed == true)
        #expect(p.isPro == true)
        #expect(p.proExpiryDate == expiry)
        #expect(p.isProActive == true)
    }

    @Test("A renewal extends the stored expiry")
    func renewalExtends() {
        let p = UserProgress()
        let first = Date().addingTimeInterval(60 * 60 * 24 * 30)
        let renewed = Date().addingTimeInterval(60 * 60 * 24 * 60)
        ProEntitlement.apply(expiry: first, to: p)
        let changed = ProEntitlement.apply(expiry: renewed, to: p)
        #expect(changed == true)
        #expect(p.proExpiryDate == renewed)
    }

    @Test("Nil expiry never modifies the record (no local revocation)")
    func nilExpiryIsNoOp() {
        let p = UserProgress()
        p.isPro = true
        let existing = Date().addingTimeInterval(60 * 60 * 24 * 365)
        p.proExpiryDate = existing
        let changed = ProEntitlement.apply(expiry: nil, to: p)
        #expect(changed == false)
        #expect(p.isPro == true)
        #expect(p.proExpiryDate == existing)
    }

    @Test("An earlier expiry never shortens a longer existing entitlement")
    func earlierExpiryDoesNotDowngrade() {
        let p = UserProgress()
        p.isPro = true
        let longer = Date().addingTimeInterval(60 * 60 * 24 * 365)
        p.proExpiryDate = longer
        let changed = ProEntitlement.apply(expiry: Date().addingTimeInterval(60), to: p)
        #expect(changed == false)
        #expect(p.proExpiryDate == longer)
    }

    @Test("A lapsed (past) stored expiry still upgrades to a new future one")
    func lapsedThenResubscribed() {
        let p = UserProgress()
        p.isPro = true
        p.proExpiryDate = Date().addingTimeInterval(-60 * 60 * 24)
        #expect(p.isProActive == false)
        let newExpiry = Date().addingTimeInterval(60 * 60 * 24 * 30)
        ProEntitlement.apply(expiry: newExpiry, to: p)
        #expect(p.isProActive == true)
        #expect(p.proExpiryDate == newExpiry)
    }

    @Test("Expiry matching the stored one but with isPro=false re-grants the flag")
    func regrantsFlagWhenExpiryEqual() {
        let p = UserProgress()
        p.isPro = false
        let expiry = Date().addingTimeInterval(60 * 60 * 24 * 30)
        p.proExpiryDate = expiry
        let changed = ProEntitlement.apply(expiry: expiry, to: p)
        #expect(changed == true)
        #expect(p.isPro == true)
        #expect(p.isProActive == true)
    }
}
