package com.stackspeak.app

import android.content.Context
import androidx.room.Room
import com.stackspeak.data.content.AndroidAssetReader
import com.stackspeak.data.content.AssetReader
import com.stackspeak.data.local.AppDatabase
import com.stackspeak.data.local.DailySetDao
import com.stackspeak.data.local.ProgressDao
import com.stackspeak.data.local.ProgressLocalStore
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun appDatabase(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, "stackspeak.db").build()

    @Provides
    fun progressDao(db: AppDatabase): ProgressDao = db.progressDao()

    @Provides
    fun dailySetDao(db: AppDatabase): DailySetDao = db.dailySetDao()

    @Provides
    @Singleton
    fun progressLocalStore(dao: ProgressDao): ProgressLocalStore = ProgressLocalStore(dao)

    @Provides
    @Singleton
    fun assetReader(@ApplicationContext context: Context): AssetReader = AndroidAssetReader(context)
}
