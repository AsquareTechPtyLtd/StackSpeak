package com.stackspeak.domain

import java.io.File

/**
 * Loads the cross-platform golden fixtures from `shared/test-fixtures/`. Walks up
 * from the test working directory until it finds the dir, so it works whether
 * Gradle runs tests from the module (`android/app`) or repo root.
 */
object Fixtures {
    private val root: File by lazy {
        val start = System.getProperty("user.dir") ?: "."
        var dir: File? = File(start)
        while (dir != null && !File(dir, "shared/test-fixtures").isDirectory) {
            dir = dir.parentFile
        }
        val found = dir ?: error("shared/test-fixtures not found above $start")
        File(found, "shared/test-fixtures")
    }

    fun read(relativePath: String): String = File(root, relativePath).readText()
}
