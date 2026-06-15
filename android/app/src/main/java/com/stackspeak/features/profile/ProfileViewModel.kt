package com.stackspeak.features.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.stackspeak.data.EntitlementRepository
import com.stackspeak.data.SyncCoordinator
import com.stackspeak.data.SyncResult
import com.stackspeak.data.backend.BackendError
import com.stackspeak.data.backend.BackendService
import com.stackspeak.data.backend.EmailSignUpResult
import com.stackspeak.data.backend.TokenStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val backend: BackendService,
    private val tokens: TokenStore,
    private val entitlement: EntitlementRepository,
    private val sync: SyncCoordinator,
) : ViewModel() {

    data class UiState(
        val configured: Boolean = false,
        val linked: Boolean = false,
        val isPro: Boolean = false,
        val busy: Boolean = false,
        val message: String? = null,
    )

    private val _state = MutableStateFlow(
        UiState(configured = backend.isConfigured, linked = tokens.accountLinked, isPro = entitlement.isProActive())
    )
    val state = _state.asStateFlow()

    fun signIn(email: String, password: String) = run("Signed in") { backend.signInWithEmail(email.trim(), password) }

    fun signUp(email: String, password: String) = viewModelScope.launch {
        _state.update { it.copy(busy = true, message = null) }
        try {
            when (backend.signUpWithEmail(email.trim(), password)) {
                is EmailSignUpResult.SignedIn -> finish("Account created & signed in")
                EmailSignUpResult.ConfirmationRequired -> finish("Check your email to confirm, then sign in")
            }
        } catch (e: Throwable) { fail(e) }
    }

    fun signOut() = viewModelScope.launch {
        backend.signOut()
        _state.update { it.copy(linked = false, message = "Signed out") }
    }

    /** Debug-only: M6 billing will drive this from real purchases. */
    fun toggleProDebug() {
        entitlement.setProActive(!entitlement.isProActive())
        _state.update { it.copy(isPro = entitlement.isProActive()) }
    }

    fun syncNow() = viewModelScope.launch {
        _state.update { it.copy(busy = true, message = null) }
        val result = sync.syncIfEligible()
        _state.update {
            it.copy(busy = false, message = when (result) {
                SyncResult.Synced -> "Synced ✓"
                is SyncResult.Skipped -> "Sync skipped: ${result.reason}"
                is SyncResult.Failed -> "Sync failed: ${result.error.message}"
            })
        }
    }

    private fun run(successMsg: String, block: suspend () -> Unit) = viewModelScope.launch {
        _state.update { it.copy(busy = true, message = null) }
        try { block(); finish(successMsg) } catch (e: Throwable) { fail(e) }
    }

    private fun finish(msg: String) = _state.update { it.copy(busy = false, linked = tokens.accountLinked, message = msg) }
    private fun fail(e: Throwable) = _state.update {
        it.copy(busy = false, message = (e as? BackendError)?.message ?: "Something went wrong")
    }
}
