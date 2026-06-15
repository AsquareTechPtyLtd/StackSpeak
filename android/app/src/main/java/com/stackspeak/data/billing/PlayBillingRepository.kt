package com.stackspeak.data.billing

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.stackspeak.data.EntitlementRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Google Play Billing implementation of [PurchaseRepository]. Connects, loads the
 * Pro subscription products, runs the purchase flow, and reconciles owned
 * purchases into [EntitlementRepository] via the pure [Entitlements] logic.
 *
 * NOTE: not headlessly verifiable — needs Play Console products + a license-test
 * account + an uploaded build. The entitlement mapping is unit-tested separately.
 */
@Singleton
class PlayBillingRepository @Inject constructor(
    @ApplicationContext private val context: Context,
    private val entitlement: EntitlementRepository,
) : PurchaseRepository, PurchasesUpdatedListener {

    private val _products = MutableStateFlow<List<ProProduct>>(emptyList())
    override val products = _products.asStateFlow()

    private val detailsBySku = mutableMapOf<String, ProductDetails>()

    private val client: BillingClient = BillingClient.newBuilder(context)
        .setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .build()

    override fun start() {
        if (client.isReady) {
            loadProducts(); reconcile(); return
        }
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    loadProducts(); reconcile()
                }
            }
            override fun onBillingServiceDisconnected() { /* reconnect lazily on next start() */ }
        })
    }

    override fun refresh() {
        if (client.isReady) reconcile() else start()
    }

    override fun purchase(activity: Activity, productId: String) {
        val details = detailsBySku[productId] ?: return
        val offerToken = details.subscriptionOfferDetails?.firstOrNull()?.offerToken ?: return
        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(
                listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder()
                        .setProductDetails(details)
                        .setOfferToken(offerToken)
                        .build()
                )
            )
            .build()
        client.launchBillingFlow(activity, params)
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) {
        if (result.responseCode == BillingClient.BillingResponseCode.OK) {
            purchases?.forEach(::handlePurchase)
        }
        reconcileFrom(purchases ?: emptyList())
    }

    private fun loadProducts() {
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                ProSku.all.map {
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(it)
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build()
                }
            )
            .build()
        client.queryProductDetailsAsync(params) { result, list ->
            if (result.responseCode != BillingClient.BillingResponseCode.OK) return@queryProductDetailsAsync
            detailsBySku.clear()
            list.forEach { detailsBySku[it.productId] = it }
            _products.value = list.map { pd ->
                val price = pd.subscriptionOfferDetails?.firstOrNull()
                    ?.pricingPhases?.pricingPhaseList?.firstOrNull()?.formattedPrice ?: ""
                ProProduct(pd.productId, pd.title, price)
            }
        }
    }

    private fun reconcile() {
        client.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build()
        ) { _, purchases -> reconcileFrom(purchases) }
    }

    private fun reconcileFrom(purchases: List<Purchase>) {
        purchases.forEach(::handlePurchase)
        val owned = purchases.map {
            Entitlements.OwnedPurchase(
                productIds = it.products,
                isPurchased = it.purchaseState == Purchase.PurchaseState.PURCHASED,
                isAcknowledged = it.isAcknowledged,
            )
        }
        entitlement.setProActive(Entitlements.isProFromPurchases(owned))
    }

    /** Acknowledge a purchase (required within 3 days or Play auto-refunds). */
    private fun handlePurchase(purchase: Purchase) {
        if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED && !purchase.isAcknowledged) {
            client.acknowledgePurchase(
                AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()
            ) { reconcile() }
        }
    }
}
