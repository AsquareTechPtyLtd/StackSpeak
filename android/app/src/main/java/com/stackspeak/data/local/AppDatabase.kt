package com.stackspeak.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [
        UserProgressEntity::class,
        ReviewStateEntity::class,
        AssessmentResultEntity::class,
        PracticedSentenceEntity::class,
        BookProgressEntity::class,
        DailySetEntity::class,
    ],
    version = 1,
    exportSchema = false,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun progressDao(): ProgressDao
    abstract fun dailySetDao(): DailySetDao
}
