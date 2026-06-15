package com.stackspeak.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.stackspeak.data.ProgressRepository
import com.stackspeak.data.UserProgress
import com.stackspeak.data.billing.PurchaseRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/** Top-level routing state: null progress = still loading, then onboarding vs main. */
@HiltViewModel
class AppViewModel @Inject constructor(
    private val progress: ProgressRepository,
    private val purchases: PurchaseRepository,
) : ViewModel() {
    val state: StateFlow<UserProgress?> = progress.state

    init {
        viewModelScope.launch { progress.ensureLoaded() }
        // Connect to the store + reconcile Pro entitlement from existing purchases.
        purchases.start()
    }
}
