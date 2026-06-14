package com.stackspeak.app

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

/** Hilt's application entry point. The DI graph is rooted here. */
@HiltAndroidApp
class StackSpeakApplication : Application()
