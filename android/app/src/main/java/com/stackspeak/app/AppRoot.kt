package com.stackspeak.app

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.stackspeak.designsystem.LocalStackSpeakColors
import com.stackspeak.features.books.BookDetailScreen
import com.stackspeak.features.books.ReaderScreen
import com.stackspeak.features.onboarding.OnboardingScreen
import com.stackspeak.features.practice.PracticeScreen

/** Manual in-app routing (no nav library needed for the loop + books). */
private sealed interface Route {
    data object Main : Route
    data class Practice(val wordId: String) : Route
    data class BookDetail(val bookId: String) : Route
    data class Reader(val bookId: String, val chapterId: String) : Route
}

@Composable
fun AppRoot() {
    val appVm: AppViewModel = hiltViewModel()
    val progress by appVm.state.collectAsStateWithLifecycle()
    val colors = LocalStackSpeakColors.current

    Surface(modifier = Modifier.fillMaxSize(), color = colors.bg) {
        when {
            progress == null -> Box(Modifier.fillMaxSize(), Alignment.Center) {
                CircularProgressIndicator(color = colors.accent)
            }
            progress?.didCompleteOnboarding != true -> OnboardingScreen()
            else -> {
                var route by remember { mutableStateOf<Route>(Route.Main) }
                when (val r = route) {
                    Route.Main -> MainScaffold(
                        onOpenWord = { route = Route.Practice(it) },
                        onOpenBook = { route = Route.BookDetail(it) },
                    )
                    is Route.Practice -> PracticeScreen(
                        wordId = r.wordId,
                        onDone = { route = Route.Main },
                    )
                    is Route.BookDetail -> BookDetailScreen(
                        bookId = r.bookId,
                        onOpenChapter = { route = Route.Reader(r.bookId, it) },
                        onBack = { route = Route.Main },
                    )
                    is Route.Reader -> ReaderScreen(
                        bookId = r.bookId,
                        chapterId = r.chapterId,
                        onBack = { route = Route.BookDetail(r.bookId) },
                    )
                }
            }
        }
    }
}
