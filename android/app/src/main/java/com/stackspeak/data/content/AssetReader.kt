package com.stackspeak.data.content

import android.content.Context

/** Reads a bundled asset by its path relative to the assets root. Seam so loaders
 *  stay testable (the JVM tests pass a file-backed reader instead). */
fun interface AssetReader {
    fun read(path: String): String
}

/** Production reader backed by the APK's AssetManager. */
class AndroidAssetReader(private val context: Context) : AssetReader {
    override fun read(path: String): String =
        context.assets.open(path).bufferedReader().use { it.readText() }
}
