package com.stackspeak.features.books

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.stackspeak.data.content.BookSummary
import com.stackspeak.designsystem.LocalStackSpeakColors
import com.stackspeak.designsystem.StackSpeakTypography

@Composable
fun LibraryScreen(onOpenBook: (String) -> Unit, viewModel: LibraryViewModel = hiltViewModel()) {
    val books by viewModel.books_.collectAsStateWithLifecycle()
    val colors = LocalStackSpeakColors.current

    Column(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
        Text("Library", style = StackSpeakTypography.title1Serif, color = colors.ink, modifier = Modifier.padding(top = 20.dp, bottom = 8.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxSize()) {
            items(books, key = { it.id }) { book -> BookCardRow(book) { onOpenBook(book.id) } }
        }
    }
}

@Composable
private fun BookCardRow(book: BookSummary, onClick: () -> Unit) {
    val colors = LocalStackSpeakColors.current
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(colors.surface).clickable(onClick = onClick).padding(16.dp),
    ) {
        Text(book.title, style = StackSpeakTypography.headline, color = colors.ink)
        if (!book.author.isNullOrBlank()) {
            Text(book.author, style = StackSpeakTypography.footnote, color = colors.inkFaint)
        }
        Text(book.summary, style = StackSpeakTypography.footnote, color = colors.inkMuted, maxLines = 3, modifier = Modifier.padding(top = 4.dp))
        Text(
            "${book.chapterCount} chapters · ${book.cardCount} cards${if (book.freeForAll) "" else " · Pro"}",
            style = StackSpeakTypography.caption, color = colors.accent, modifier = Modifier.padding(top = 6.dp),
        )
    }
}
