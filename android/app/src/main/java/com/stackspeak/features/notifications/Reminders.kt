package com.stackspeak.features.notifications

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.stackspeak.R
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

const val REMINDER_CHANNEL_ID = "daily_reminder"
private const val REMINDER_WORK = "stackspeak_daily_reminder"

/** Creates the daily-reminder notification channel (call once at app start). */
fun createReminderChannel(context: Context) {
    val channel = NotificationChannel(
        REMINDER_CHANNEL_ID,
        "Daily reminder",
        NotificationManager.IMPORTANCE_DEFAULT,
    ).apply { description = "Your daily 5 words are ready." }
    context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
}

/** Posts the daily reminder. Silently no-ops if notifications aren't permitted. */
class ReminderWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val granted = ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) {
            val notification = NotificationCompat.Builder(applicationContext, REMINDER_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle("Today's words are ready")
                .setContentText("Five minutes, five technical words. Keep your streak alive.")
                .setAutoCancel(true)
                .build()
            runCatching { NotificationManagerCompat.from(applicationContext).notify(1, notification) }
        }
        return Result.success()
    }
}

/** Schedules / cancels the daily reminder via WorkManager. */
@Singleton
class ReminderScheduler @Inject constructor(@ApplicationContext private val context: Context) {
    fun setEnabled(enabled: Boolean) {
        val wm = WorkManager.getInstance(context)
        if (!enabled) {
            wm.cancelUniqueWork(REMINDER_WORK)
            return
        }
        val request = PeriodicWorkRequestBuilder<ReminderWorker>(1, TimeUnit.DAYS).build()
        wm.enqueueUniquePeriodicWork(REMINDER_WORK, ExistingPeriodicWorkPolicy.KEEP, request)
    }
}
