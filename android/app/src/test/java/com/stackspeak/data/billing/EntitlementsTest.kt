package com.stackspeak.data.billing

import com.stackspeak.data.billing.Entitlements.OwnedPurchase
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** M6: the purchase → Pro mapping (the BillingClient-independent, testable core). */
class EntitlementsTest {

    @Test
    fun proWhenOwnedAcknowledgedProSubscription() {
        assertTrue(Entitlements.isProFromPurchases(listOf(OwnedPurchase(listOf(ProSku.MONTHLY), isPurchased = true, isAcknowledged = true))))
        assertTrue(Entitlements.isProFromPurchases(listOf(OwnedPurchase(listOf(ProSku.YEARLY), isPurchased = true, isAcknowledged = true))))
    }

    @Test
    fun notProWhenUnacknowledged() {
        assertFalse(Entitlements.isProFromPurchases(listOf(OwnedPurchase(listOf(ProSku.MONTHLY), isPurchased = true, isAcknowledged = false))))
    }

    @Test
    fun notProWhenPending() {
        assertFalse(Entitlements.isProFromPurchases(listOf(OwnedPurchase(listOf(ProSku.YEARLY), isPurchased = false, isAcknowledged = true))))
    }

    @Test
    fun notProForUnknownProduct() {
        assertFalse(Entitlements.isProFromPurchases(listOf(OwnedPurchase(listOf("com.other.thing"), isPurchased = true, isAcknowledged = true))))
    }

    @Test
    fun emptyIsNotPro() {
        assertFalse(Entitlements.isProFromPurchases(emptyList()))
    }
}
