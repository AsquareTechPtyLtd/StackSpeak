package com.stackspeak.features.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.stackspeak.designsystem.LocalStackSpeakColors
import com.stackspeak.designsystem.StackSpeakTypography

@Composable
fun ProfileScreen(viewModel: ProfileViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val products by viewModel.products.collectAsStateWithLifecycle()
    val colors = LocalStackSpeakColors.current
    val activity = LocalContext.current as? android.app.Activity
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    val notifPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) viewModel.setReminders(true)
    }

    Column(Modifier.fillMaxSize().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Profile", style = StackSpeakTypography.title1Serif, color = colors.ink)

        if (!state.configured) {
            Text("Sync isn't configured in this build.", style = StackSpeakTypography.callout, color = colors.inkMuted)
            return@Column
        }

        if (state.linked) {
            Text("Signed in ✓", style = StackSpeakTypography.headline, color = colors.good)
            TextButton(onClick = viewModel::signOut) { Text("Sign out", color = colors.accent) }
        } else {
            Text("Sign in to sync across devices (Pro).", style = StackSpeakTypography.callout, color = colors.inkMuted)
            OutlinedTextField(
                value = email, onValueChange = { email = it },
                label = { Text("Email") }, singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = password, onValueChange = { password = it },
                label = { Text("Password") }, singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                modifier = Modifier.fillMaxWidth(),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = { viewModel.signIn(email, password) },
                    enabled = !state.busy && email.isNotBlank() && password.isNotBlank(),
                    colors = ButtonDefaults.buttonColors(containerColor = colors.accent, contentColor = colors.accentText),
                    modifier = Modifier.weight(1f),
                ) { Text("Sign in") }
                Button(
                    onClick = { viewModel.signUp(email, password) },
                    enabled = !state.busy && email.isNotBlank() && password.isNotBlank(),
                    colors = ButtonDefaults.buttonColors(containerColor = colors.surfaceAlt, contentColor = colors.ink),
                    modifier = Modifier.weight(1f),
                ) { Text("Sign up") }
            }
        }

        // Pro debug toggle (M6 billing replaces this) + manual sync.
        Row(
            Modifier.fillMaxWidth().background(colors.surface, RoundedCornerShape(12.dp)).padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Pro (debug)", style = StackSpeakTypography.body, color = colors.ink)
            Switch(checked = state.isPro, onCheckedChange = { viewModel.toggleProDebug() })
        }
        Row(
            Modifier.fillMaxWidth().background(colors.surface, RoundedCornerShape(12.dp)).padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Daily reminder", style = StackSpeakTypography.body, color = colors.ink)
            Switch(
                checked = state.remindersEnabled,
                onCheckedChange = { on ->
                    if (on) notifPermission.launch(android.Manifest.permission.POST_NOTIFICATIONS)
                    else viewModel.setReminders(false)
                },
            )
        }
        Button(
            onClick = viewModel::syncNow,
            enabled = !state.busy,
            colors = ButtonDefaults.buttonColors(containerColor = colors.accent, contentColor = colors.accentText),
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Sync now") }

        // Paywall — real Pro purchase (subscriptions). Hidden once Pro is active.
        if (!state.isPro && products.isNotEmpty()) {
            Text("Get StackSpeak Pro", style = StackSpeakTypography.headline, color = colors.ink)
            products.forEach { product ->
                Button(
                    onClick = { activity?.let { viewModel.buyPro(it, product.id) } },
                    colors = ButtonDefaults.buttonColors(containerColor = colors.accentDecoration, contentColor = colors.accentText),
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("${product.title} — ${product.formattedPrice}") }
            }
        }

        state.message?.let { Text(it, style = StackSpeakTypography.footnote, color = colors.inkMuted) }
    }
}
