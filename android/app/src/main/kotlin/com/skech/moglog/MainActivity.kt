package com.skech.moglog

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.PersistableBundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.MediaStore
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin

class MainActivity : FlutterFragmentActivity() {

    private val channelName = "com.skech.moglog/platform"
    private val allowedDeepLinkTargets = setOf("watch_circle")
    private val allowedLaunchSchemes = setOf("https", "nflx")
    private val safePackageRegex = Regex("^[a-zA-Z0-9_]+(\\.[a-zA-Z0-9_]+)+$")

    private var methodChannel: MethodChannel? = null
    private var pendingOpenDramaId: Int = -1
    private var pendingNavigateTarget: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableHighRefreshRateDisplay()
        extractDeepLinkIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        enableHighRefreshRateDisplay()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            enableHighRefreshRateDisplay()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractDeepLinkIntent(intent)
        dispatchPendingDeepLink()
    }

    private fun extractDeepLinkIntent(intent: Intent?) {
        if (intent == null) return
        val dramaId = intent.getIntExtra("open_drama_id", -1)
        if (dramaId > 0) {
            pendingOpenDramaId = dramaId
            intent.removeExtra("open_drama_id")
        }
        val target = intent.getStringExtra("navigate_to")?.trim()
        if (!target.isNullOrEmpty() && target in allowedDeepLinkTargets) {
            pendingNavigateTarget = target
            intent.removeExtra("navigate_to")
        }
    }

    private fun dispatchPendingDeepLink() {
        val channel = methodChannel ?: return
        if (pendingOpenDramaId > 0) {
            val id = pendingOpenDramaId
            pendingOpenDramaId = -1
            channel.invokeMethod("onDeepLink", mapOf("open_drama_id" to id))
        }
        val target = pendingNavigateTarget
        if (!target.isNullOrBlank()) {
            pendingNavigateTarget = null
            channel.invokeMethod("onDeepLink", mapOf("navigate_to" to target))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "migrateLegacyKotlinData" -> {
                        Thread {
                            val payload = try {
                                LegacyKotlinMigration.readLegacyKotlinPayload(applicationContext)
                            } catch (_: Exception) {
                                null
                            }
                            runOnUiThread { result.success(payload) }
                        }.start()
                    }
                    "markLegacyKotlinMigrationComplete" -> {
                        LegacyKotlinMigration.markMigrationCompleted(applicationContext)
                        result.success(true)
                    }
                    "migrateV9EncryptedPrefs" -> {
                        Thread {
                            val migrated = try {
                                LegacyKotlinMigration.readFlutterV9EncryptedPrefs(applicationContext)
                            } catch (_: Exception) {
                                null
                            }
                            runOnUiThread { result.success(migrated) }
                        }.start()
                    }
                    "purgeV9EncryptedPrefs" -> {
                        LegacyKotlinMigration.purgeFlutterV9EncryptedPrefs(applicationContext)
                        result.success(true)
                    }
                    "copySensitiveClipboard" -> {
                        val label = call.argument<String>("label") ?: "Moglog"
                        val text = call.argument<String>("text") ?: ""
                        copySensitiveClipboard(label, text)
                        result.success(true)
                    }
                    "syncEpisodeReminderWorker" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val watchingJson = call.argument<String>("watchingJson") ?: "[]"
                        val runImmediate = call.argument<Boolean>("runImmediate") ?: false
                        EpisodeReminderWorker.syncAndSchedule(
                            context = applicationContext,
                            enabled = enabled,
                            watchingJson = watchingJson,
                            runImmediate = runImmediate
                        )
                        result.success(true)
                    }
                    "setFlagSecure" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            if (enabled) {
                                window.setFlags(
                                    WindowManager.LayoutParams.FLAG_SECURE,
                                    WindowManager.LayoutParams.FLAG_SECURE
                                )
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                        }
                        result.success(true)
                    }
                    "isPackageInstalled" -> {
                        val pkg = call.argument<String>("packageName").orEmpty().trim()
                        val installed = try {
                            pkg.matches(safePackageRegex) &&
                                packageManager.getLaunchIntentForPackage(pkg) != null
                        } catch (_: Exception) {
                            false
                        }
                        result.success(installed)
                    }
                    "launchPackageDeepLink" -> {
                        val pkg = call.argument<String>("packageName").orEmpty().trim()
                        val uriStr = call.argument<String>("uri").orEmpty().trim()
                        val launched = try {
                            val parsed = Uri.parse(uriStr)
                            val scheme = parsed.scheme?.lowercase()
                            if (scheme == null || scheme !in allowedLaunchSchemes) {
                                false
                            } else {
                                val intent = Intent(Intent.ACTION_VIEW, parsed).apply {
                                    addCategory(Intent.CATEGORY_BROWSABLE)
                                    if (pkg.matches(safePackageRegex)) setPackage(pkg)
                                }
                                startActivity(intent)
                                true
                            }
                        } catch (_: Exception) {
                            false
                        }
                        result.success(launched)
                    }
                    "saveImageToGallery" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName") ?: "Moglog_Wrapped.png"
                        if (bytes == null) {
                            result.success(false)
                        } else {
                            result.success(savePngToGallery(bytes, fileName))
                        }
                    }
                    "playCompletionChime" -> {
                        playCompletionChime()
                        result.success(true)
                    }
                    "playVictoryHaptic" -> {
                        playVictoryHaptic()
                        result.success(true)
                    }
                    "playPulseHaptic" -> {
                        val durationMs = (call.argument<Int>("durationMs") ?: 14).toLong()
                        val amplitude = call.argument<Int>("amplitude") ?: 90
                        playPulseHaptic(durationMs, amplitude)
                        result.success(true)
                    }
                    "consumePendingDeepLink" -> {
                        val payload = mutableMapOf<String, Any>()
                        if (pendingOpenDramaId > 0) {
                            payload["open_drama_id"] = pendingOpenDramaId
                            pendingOpenDramaId = -1
                        }
                        val target = pendingNavigateTarget
                        if (!target.isNullOrBlank()) {
                            payload["navigate_to"] = target
                            pendingNavigateTarget = null
                        }
                        result.success(if (payload.isEmpty()) null else payload)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun copySensitiveClipboard(label: String, text: String) {
        try {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return
            val clip = ClipData.newPlainText(label, text)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                clip.description.extras = PersistableBundle().apply {
                    putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
                }
            } else {
                clip.description.extras = PersistableBundle().apply {
                    putBoolean("android.content.extra.IS_SENSITIVE", true)
                }
            }
            clipboard.setPrimaryClip(clip)
        } catch (_: Exception) {
        }
    }

    private fun savePngToGallery(bytes: ByteArray, fileName: String): Boolean {
        val resolver = contentResolver
        var insertedUri: Uri? = null
        return try {
            val cleanBase = File(fileName).name.replace(Regex("[^a-zA-Z0-9._-]"), "_")
            val safeName = if (cleanBase.lowercase().endsWith(".png")) cleanBase else "$cleanBase.png"
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, safeName)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/Moglog")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
            }
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                ?: return false
            insertedUri = uri
            val stream = resolver.openOutputStream(uri) ?: run {
                runCatching { resolver.delete(uri, null, null) }
                return false
            }
            stream.use { out ->
                out.write(bytes)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentValues.clear()
                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, contentValues, null, null)
            }
            true
        } catch (_: Exception) {
            insertedUri?.let { uri ->
                runCatching { resolver.delete(uri, null, null) }
            }
            false
        }
    }

    /**
     * Exact 1:1 port of CelebrationAudio.playCompletionChime (C6 -> E6 -> G6 PCM arpeggio).
     */
    private fun playCompletionChime() {
        Thread {
            var audioTrack: AudioTrack? = null
            try {
                val sampleRate = 44100
                val durationSec = 0.60
                val totalSamples = (sampleRate * durationSec).toInt()
                val buffer = ShortArray(totalSamples)
                val notes = listOf(
                    Triple(0.00, 0.22, 1046.50),
                    Triple(0.10, 0.32, 1318.51),
                    Triple(0.20, 0.60, 1567.98)
                )
                for (i in 0 until totalSamples) {
                    val t = i.toDouble() / sampleRate
                    var sample = 0.0
                    for ((start, end, freq) in notes) {
                        if (t in start..end) {
                            val localT = t - start
                            val attack = (localT / 0.015).coerceIn(0.0, 1.0)
                            val decay = Math.exp(-localT * 7.5)
                            val amp = attack * decay * 0.32
                            sample += amp * (sin(2.0 * PI * freq * localT) + 0.25 * sin(4.0 * PI * freq * localT))
                        }
                    }
                    buffer[i] = (sample.coerceIn(-1.0, 1.0) * Short.MAX_VALUE).toInt().toShort()
                }
                val track = AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(buffer.size * 2)
                    .setTransferMode(AudioTrack.MODE_STATIC)
                    .build()
                audioTrack = track
                track.write(buffer, 0, buffer.size)
                track.play()
                Thread.sleep(700)
            } catch (_: Exception) {
            } finally {
                runCatching { audioTrack?.stop() }
                runCatching { audioTrack?.release() }
            }
        }.start()
    }

    private fun getVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            vm?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private fun playVictoryHaptic() {
        try {
            val vibrator = getVibrator() ?: return
            if (!vibrator.hasVibrator()) return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val timings = longArrayOf(0, 45, 55, 45, 55, 110)
                val amplitudes = intArrayOf(0, 160, 0, 200, 0, 255)
                vibrator.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(longArrayOf(0, 45, 55, 45, 55, 110), -1)
            }
        } catch (_: Exception) {
        }
    }

    private fun playPulseHaptic(durationMs: Long, amplitude: Int) {
        try {
            val vibrator = getVibrator() ?: return
            if (!vibrator.hasVibrator()) return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(
                    VibrationEffect.createOneShot(
                        durationMs.coerceAtLeast(1L),
                        amplitude.coerceIn(1, 255)
                    )
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(durationMs)
            }
        } catch (_: Exception) {
        }
    }

    /**
     * Requests 60Hz-120Hz display refresh rate matching native resolution (1:1 parity with Kotlin).
     */
    private fun enableHighRefreshRateDisplay() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val activeDisplay = display ?: return
                val currentMode = activeDisplay.mode
                val bestMode = activeDisplay.supportedModes
                    .filter {
                        it.physicalWidth == currentMode.physicalWidth &&
                            it.physicalHeight == currentMode.physicalHeight &&
                            it.refreshRate in 60f..120.5f
                    }
                    .maxByOrNull { it.refreshRate }
                    ?: activeDisplay.supportedModes
                        .filter {
                            it.physicalWidth == currentMode.physicalWidth &&
                                it.physicalHeight == currentMode.physicalHeight
                        }
                        .minByOrNull { abs(it.refreshRate - 120f) }

                if (bestMode != null && window.attributes.preferredDisplayModeId != bestMode.modeId) {
                    val params = window.attributes
                    params.preferredDisplayModeId = bestMode.modeId
                    window.attributes = params
                }
            }
        } catch (_: Exception) {
        }
    }
}
