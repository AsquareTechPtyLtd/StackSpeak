package com.stackspeak.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Pro entitlement — per-device, NOT synced (each store derives Pro independently).
 * A stub for M5: defaults to false with a debug setter so sync can be exercised.
 * M6 (Play Billing) will drive [setProActive] from real purchases.
 */
@Singleton
class EntitlementRepository @Inject constructor() {
    private val _isPro = MutableStateFlow(false)
    val isProFlow = _isPro.asStateFlow()

    fun isProActive(): Boolean = _isPro.value
    fun setProActive(active: Boolean) { _isPro.value = active }
}
