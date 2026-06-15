package com.stackspeak.data.billing

import android.app.Activity
import kotlinx.coroutines.flow.StateFlow

/** StackSpeak Pro product ids (define these in Play Console → Subscriptions). */
object ProSku {
    const val MONTHLY = "com.stackspeak.android.pro.monthly"
    const val YEARLY = "com.stackspeak.android.pro.yearly"
    val all = listOf(MONTHLY, YEARLY)
}

/** A purchasable Pro plan (resolved from Play's ProductDetails). */
data class ProProduct(val id: String, val title: String, val formattedPrice: String)

/** The store seam — only [PlayBillingRepository] knows it's Google Play. */
interface PurchaseRepository {
    val products: StateFlow<List<ProProduct>>
    /** Connect to the store, load products, and reconcile existing entitlements. */
    fun start()
    /** Launch the purchase flow for a Pro product. */
    fun purchase(activity: Activity, productId: String)
    /** Re-query owned purchases and refresh entitlement (e.g. after sign-in). */
    fun refresh()
}

/**
 * Pure entitlement logic, decoupled from BillingClient so it's unit-testable: a
 * user is Pro if they own any *purchased + acknowledged* StackSpeak Pro product.
 * (Acknowledged-gating mirrors Play's "must acknowledge within 3 days or refund".)
 */
object Entitlements {
    data class OwnedPurchase(val productIds: List<String>, val isPurchased: Boolean, val isAcknowledged: Boolean)

    fun isProFromPurchases(purchases: List<OwnedPurchase>): Boolean =
        purchases.any { p -> p.isPurchased && p.isAcknowledged && p.productIds.any { it in ProSku.all } }
}
