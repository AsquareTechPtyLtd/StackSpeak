package com.stackspeak.app

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.stackspeak.designsystem.LocalStackSpeakColors
import com.stackspeak.designsystem.StackSpeakTypography
import com.stackspeak.features.books.LibraryScreen
import com.stackspeak.features.home.HomeScreen
import com.stackspeak.features.review.ReviewScreen

@Composable
fun MainScaffold(onOpenWord: (String) -> Unit, onOpenBook: (String) -> Unit) {
    var tab by remember { mutableIntStateOf(0) }
    val colors = LocalStackSpeakColors.current

    Column(Modifier.fillMaxSize()) {
        Column(Modifier.weight(1f)) {
            when (tab) {
                0 -> HomeScreen(onOpenWord = onOpenWord)
                1 -> ReviewScreen()
                else -> LibraryScreen(onOpenBook = onOpenBook)
            }
        }
        Row(
            Modifier
                .fillMaxWidth()
                .background(colors.surface)
                .padding(vertical = 10.dp),
        ) {
            TabLabel("Today", selected = tab == 0, modifier = Modifier.weight(1f)) { tab = 0 }
            TabLabel("Review", selected = tab == 1, modifier = Modifier.weight(1f)) { tab = 1 }
            TabLabel("Library", selected = tab == 2, modifier = Modifier.weight(1f)) { tab = 2 }
        }
    }
}

@Composable
private fun TabLabel(text: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val colors = LocalStackSpeakColors.current
    Text(
        text = text,
        style = StackSpeakTypography.headline,
        color = if (selected) colors.accent else colors.inkMuted,
        textAlign = TextAlign.Center,
        modifier = modifier
            .clickable(onClick = onClick)
            .padding(vertical = 4.dp),
    )
}
