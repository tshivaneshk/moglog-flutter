package com.skech.moglog

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit

/**
 * Killed-process Android WorkManager periodic worker (1:1 parity with Kotlin EpisodeReminderWorker).
 * Runs every 12 hours even when the app is completely closed, checking synced Watching shows
 * against today's ISO air date and posting rich BigPictureStyle notifications.
 */
class EpisodeReminderWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        return try {
            val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean(KEY_ENABLED, false)
            if (!enabled || !hasNotificationPermission(applicationContext)) {
                return Result.success()
            }

            ensureNotificationChannel(applicationContext)

            val rawJson = prefs.getString(KEY_WATCHING_JSON, "[]") ?: "[]"
            val arr = JSONArray(rawJson)
            val todayIso = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                val airDate = obj.optString("nextEpisodeAirDate", "").trim()
                if (airDate.isNotEmpty() && airDate.startsWith(todayIso)) {
                    val dramaId = obj.optInt("id", 0)
                    val title = obj.optString("title", "")
                    if (dramaId <= 0 || title.isBlank()) continue
                    val season = obj.optInt("season", 1).coerceAtLeast(1)
                    val episode = obj.optInt("episode", 0)
                    val overview = obj.optString("overview", "")
                    val posterUrl = obj.optString("posterPath", "")
                    val posterBitmap = loadPosterBitmap(posterUrl)

                    postEpisodeNotification(
                        context = applicationContext,
                        dramaId = dramaId,
                        title = title,
                        season = season,
                        episode = episode,
                        overview = overview,
                        posterBitmap = posterBitmap
                    )
                }
            }
            Result.success()
        } catch (_: Exception) {
            Result.retry()
        }
    }

    companion object {
        const val WORK_NAME = "moglog_episode_reminder_worker"
        private const val PREFS_NAME = "moglog_worker_cache"
        private const val KEY_ENABLED = "episode_reminders_enabled"
        private const val KEY_WATCHING_JSON = "watching_shows_json"
        private const val CHANNEL_ID = "moglog_episode_reminders"
        private const val MOGLOG_ACCENT_COLOR = 0xFF30D158.toInt()

        fun syncAndSchedule(
            context: Context,
            enabled: Boolean,
            watchingJson: String,
            runImmediate: Boolean
        ) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_ENABLED, enabled)
                .putString(KEY_WATCHING_JSON, watchingJson)
                .apply()

            val wm = WorkManager.getInstance(context)
            if (enabled) {
                val periodic = PeriodicWorkRequestBuilder<EpisodeReminderWorker>(
                    12, TimeUnit.HOURS
                ).build()
                wm.enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    periodic
                )
                if (runImmediate) {
                    wm.enqueue(OneTimeWorkRequestBuilder<EpisodeReminderWorker>().build())
                }
            } else {
                wm.cancelUniqueWork(WORK_NAME)
            }
        }

        private fun hasNotificationPermission(context: Context): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS
                ) == PackageManager.PERMISSION_GRANTED
            } else {
                true
            }
        }

        private fun ensureNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Episode Air-Date Reminders",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Alerts when a show in your Watching list airs a new episode"
                    enableLights(true)
                    lightColor = MOGLOG_ACCENT_COLOR
                }
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                nm?.createNotificationChannel(channel)
            }
        }

        private suspend fun loadPosterBitmap(posterUrl: String): Bitmap? {
            if (posterUrl.isBlank()) return null
            return withContext(Dispatchers.IO) {
                try {
                    val conn = URL(posterUrl).openConnection() as HttpURLConnection
                    conn.connectTimeout = 6000
                    conn.readTimeout = 6000
                    conn.inputStream.use { stream ->
                        BitmapFactory.decodeStream(stream)
                    }
                } catch (_: Exception) {
                    null
                }
            }
        }

        private fun postEpisodeNotification(
            context: Context,
            dramaId: Int,
            title: String,
            season: Int,
            episode: Int,
            overview: String,
            posterBitmap: Bitmap?
        ) {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_drama_id", dramaId)
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                dramaId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val epBadge = if (episode > 0) "Season $season · Episode $episode" else "New Episode"
            val shortText = "$epBadge drops today! Tap to log your watch progress."
            val expandedSummary = buildString {
                append("$epBadge airs today.")
                if (overview.isNotBlank()) {
                    append("\n\n")
                    append(overview.take(180))
                    if (overview.length > 180) append("…")
                }
            }

            val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_moglog)
                .setColor(MOGLOG_ACCENT_COLOR)
                .setSubText("Moglog · Airing Today")
                .setContentTitle(title)
                .setContentText(shortText)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .addAction(R.drawable.ic_stat_moglog, "Log Episode", pendingIntent)

            if (posterBitmap != null) {
                builder.setLargeIcon(posterBitmap)
                builder.setStyle(
                    NotificationCompat.BigPictureStyle()
                        .bigPicture(posterBitmap)
                        .bigLargeIcon(null as Bitmap?)
                        .setBigContentTitle(title)
                        .setSummaryText(shortText)
                )
            } else {
                builder.setStyle(
                    NotificationCompat.BigTextStyle()
                        .setBigContentTitle(title)
                        .bigText(expandedSummary)
                        .setSummaryText("Moglog Watchlist")
                )
            }

            runCatching {
                NotificationManagerCompat.from(context).notify(dramaId, builder.build())
            }
        }
    }
}
