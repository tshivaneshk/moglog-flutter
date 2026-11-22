package com.skech.moglog

import android.content.Context
import android.database.Cursor
import android.util.Base64
import android.util.Log
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.google.crypto.tink.Aead
import com.google.crypto.tink.KeyTemplates
import com.google.crypto.tink.aead.AeadConfig
import com.google.crypto.tink.integration.android.AndroidKeysetManager
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import net.zetetic.database.sqlcipher.SQLiteDatabase
import java.io.File
import java.io.RandomAccessFile
import java.nio.charset.StandardCharsets

private val Context.legacyMoglogDataStore: DataStore<Preferences> by preferencesDataStore(name = "moglog_settings")

/**
 * One-time read-only migrator for seamless in-place upgrades from Kotlin Moglog (<= v3.0.73)
 * to Flutter Moglog (v3.1.0+) without uninstalling or losing local data:
 * 1. Decrypts Kotlin's Google Tink `moglog_secure_store` (TMDB key, backup passphrase, DB key).
 * 2. Reads all 21 preferences from Jetpack DataStore (`moglog_settings.preferences_pb`).
 * 3. Reads `dramas`, `shortcuts`, and `drama_details_cache` from SQLCipher `/databases/drama_db`.
 */
object LegacyKotlinMigration {

    private const val TAG = "LegacyKotlinMigration"
    private const val MIGRATION_PREFS = "moglog_flutter_migration_state"
    private const val KEY_MIGRATED = "kotlin_v3_migrated"

    // Exact Kotlin SecureStore constants
    private const val LEGACY_SECURE_PREFS = "moglog_secure_store"
    private const val KEYSET_PREFS_NAME = "moglog_tink_keyset_prefs"
    private const val KEYSET_NAME = "moglog_master_keyset"
    private const val FALLBACK_KEYSET_NAME = "moglog_software_recovery_keyset"
    private const val MASTER_KEY_URI = "android-keystore://moglog_tink_master_key"

    private const val KEY_TMDB_CREDENTIAL = "enc_tmdb_credential"
    private const val KEY_DB_PASSPHRASE = "enc_db_passphrase"
    private const val KEY_BACKUP_PASSPHRASE = "enc_backup_passphrase"

    private val AAD_TMDB_CREDENTIAL = "moglog:tmdb_credential:v1".toByteArray(StandardCharsets.UTF_8)
    private val AAD_DB_PASSPHRASE = "moglog:db_passphrase:v1".toByteArray(StandardCharsets.UTF_8)
    private val AAD_BACKUP_PASSPHRASE = "moglog:backup_passphrase:v1".toByteArray(StandardCharsets.UTF_8)

    private const val COMPROMISED_LEGACY_KEY = "b30d871ab7f51c18054f0e6d0921da16"
    private val SQLITE_PLAINTEXT_HEADER = "SQLite format 3\u0000".toByteArray(Charsets.US_ASCII)

    fun isMigrationCompleted(context: Context): Boolean {
        return context.getSharedPreferences(MIGRATION_PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_MIGRATED, false)
    }

    fun markMigrationCompleted(context: Context) {
        context.getSharedPreferences(MIGRATION_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_MIGRATED, true)
            .apply()
    }

    fun readLegacyKotlinPayload(context: Context): Map<String, Any?>? {
        if (isMigrationCompleted(context)) return null

        val legacyDbFile = context.getDatabasePath("drama_db")
        val datastoreFile = File(context.filesDir, "datastore/moglog_settings.preferences_pb")
        val legacySecurePrefs = context.getSharedPreferences(LEGACY_SECURE_PREFS, Context.MODE_PRIVATE)
        val legacyPlainPrefs = context.getSharedPreferences("moglog_prefs", Context.MODE_PRIVATE)

        val hasLegacyArtifacts = legacyDbFile.exists() ||
            datastoreFile.exists() ||
            legacySecurePrefs.all.isNotEmpty() ||
            legacyPlainPrefs.all.isNotEmpty()

        if (!hasLegacyArtifacts) {
            markMigrationCompleted(context)
            return null
        }

        Log.i(TAG, "Detected existing Kotlin Moglog v3.0.x installation. Reading legacy data for seamless upgrade...")

        val secrets = readLegacySecrets(context, legacySecurePrefs, legacyPlainPrefs)
        val settings = readLegacySettings(context, datastoreFile, legacyPlainPrefs)
        val dbKeyBytes = secrets.dbPassphraseBytes

        val dramas = mutableListOf<Map<String, Any?>>()
        val shortcuts = mutableListOf<Map<String, Any?>>()
        val detailCache = mutableListOf<Map<String, Any?>>()

        if (legacyDbFile.exists() && legacyDbFile.length() > 0L) {
            readLegacyDatabase(
                dbFile = legacyDbFile,
                passphraseBytes = dbKeyBytes,
                outDramas = dramas,
                outShortcuts = shortcuts,
                outDetailCache = detailCache
            )
        }

        val payload = hashMapOf<String, Any?>(
            "tmdbCredential" to secrets.tmdbCredential,
            "backupPassphrase" to secrets.backupPassphrase,
            "settings" to settings,
            "dramas" to dramas,
            "shortcuts" to shortcuts,
            "detailCache" to detailCache
        )
        Log.i(
            TAG,
            "Prepared legacy migration payload: dramas=${dramas.size}, shortcuts=${shortcuts.size}, " +
                "cache=${detailCache.size}, hasTmdb=${secrets.tmdbCredential.isNotBlank()}, settings=${settings.size}"
        )
        return payload
    }

    private data class LegacySecrets(
        val tmdbCredential: String,
        val backupPassphrase: String,
        val dbPassphraseBytes: ByteArray?
    )

    private fun readLegacySecrets(
        context: Context,
        securePrefs: android.content.SharedPreferences,
        legacyPlainPrefs: android.content.SharedPreferences
    ): LegacySecrets {
        var hwAead: Aead? = null
        var swAead: Aead? = null
        try {
            AeadConfig.register()
            hwAead = try {
                AndroidKeysetManager.Builder()
                    .withSharedPref(context, KEYSET_NAME, KEYSET_PREFS_NAME)
                    .withKeyTemplate(KeyTemplates.get("AES256_GCM"))
                    .withMasterKeyUri(MASTER_KEY_URI)
                    .build()
                    .keysetHandle
                    .getPrimitive(Aead::class.java)
            } catch (e: Exception) {
                Log.w(TAG, "Hardware Tink keyset unavailable during migration: ${e.message}")
                null
            }
            swAead = try {
                AndroidKeysetManager.Builder()
                    .withSharedPref(context, FALLBACK_KEYSET_NAME, KEYSET_PREFS_NAME)
                    .withKeyTemplate(KeyTemplates.get("AES256_GCM"))
                    .build()
                    .keysetHandle
                    .getPrimitive(Aead::class.java)
            } catch (e: Exception) {
                Log.w(TAG, "Software Tink keyset unavailable during migration: ${e.message}")
                null
            }
        } catch (e: Exception) {
            Log.w(TAG, "Tink init failed during migration: ${e.message}")
        }

        fun decrypt(key: String, aad: ByteArray): String? {
            val hwEncoded = securePrefs.getString(key, null)
            if (hwAead != null && !hwEncoded.isNullOrBlank()) {
                try {
                    val ct = Base64.decode(hwEncoded, Base64.NO_WRAP)
                    return String(hwAead.decrypt(ct, aad), StandardCharsets.UTF_8)
                } catch (_: Exception) {
                }
            }
            val swEncoded = securePrefs.getString("${key}_sw", null)
            if (swAead != null && !swEncoded.isNullOrBlank()) {
                try {
                    val ct = Base64.decode(swEncoded, Base64.NO_WRAP)
                    return String(swAead.decrypt(ct, aad), StandardCharsets.UTF_8)
                } catch (_: Exception) {
                }
            }
            val fbEncoded = securePrefs.getString("${key}_fallback", null)
            if (!fbEncoded.isNullOrBlank()) {
                try {
                    return String(Base64.decode(fbEncoded, Base64.NO_WRAP), StandardCharsets.UTF_8)
                } catch (_: Exception) {
                }
            }
            return null
        }

        var tmdb = decrypt(KEY_TMDB_CREDENTIAL, AAD_TMDB_CREDENTIAL).orEmpty().trim()
        if (tmdb.isEmpty()) {
            val plain = legacyPlainPrefs.getString("tmdb_api_key", "")?.trim().orEmpty()
            if (plain.isNotEmpty() && plain != COMPROMISED_LEGACY_KEY) {
                tmdb = plain
            }
        }
        if (tmdb == COMPROMISED_LEGACY_KEY) tmdb = ""

        val backupPass = decrypt(KEY_BACKUP_PASSPHRASE, AAD_BACKUP_PASSPHRASE).orEmpty().trim()
        val dbKeyB64 = decrypt(KEY_DB_PASSPHRASE, AAD_DB_PASSPHRASE)
        val dbKeyBytes = if (!dbKeyB64.isNullOrBlank()) {
            try {
                Base64.decode(dbKeyB64, Base64.NO_WRAP)
            } catch (_: Exception) {
                null
            }
        } else {
            null
        }

        return LegacySecrets(
            tmdbCredential = tmdb,
            backupPassphrase = backupPass,
            dbPassphraseBytes = dbKeyBytes
        )
    }

    private fun readLegacySettings(
        context: Context,
        datastoreFile: File,
        legacyPlainPrefs: android.content.SharedPreferences
    ): Map<String, Any?> {
        val result = hashMapOf<String, Any?>()

        // Fallback values from very old SharedPreferences if present
        if (legacyPlainPrefs.contains("is_first_launch")) {
            result["is_first_launch"] = legacyPlainPrefs.getBoolean("is_first_launch", false)
        }
        legacyPlainPrefs.getString("sync_frequency", null)?.let {
            result["sync_frequency"] = it
        }

        if (!datastoreFile.exists()) return result

        try {
            val prefs = runBlocking { context.legacyMoglogDataStore.data.first() }
            prefs[booleanPreferencesKey("is_first_launch")]?.let { result["is_first_launch"] = it }
            prefs[stringPreferencesKey("sync_frequency")]?.let { result["sync_frequency"] = it }
            prefs[stringPreferencesKey("theme_mode")]?.let { result["theme_mode"] = it }
            prefs[booleanPreferencesKey("dynamic_poster_tint")]?.let { result["dynamic_poster_tint"] = it }
            prefs[intPreferencesKey("grid_columns")]?.let { result["grid_columns"] = it }
            prefs[stringPreferencesKey("layout_mode")]?.let { result["layout_mode"] = it }
            prefs[booleanPreferencesKey("app_lock_enabled")]?.let { result["app_lock_enabled"] = it }
            prefs[intPreferencesKey("app_lock_timeout_sec")]?.let { result["app_lock_timeout_sec"] = it }
            prefs[booleanPreferencesKey("hide_in_recents")]?.let { result["hide_in_recents"] = it }
            prefs[booleanPreferencesKey("encrypted_cloud_backup")]?.let { result["encrypted_cloud_backup"] = it }
            prefs[booleanPreferencesKey("episode_reminders")]?.let { result["episode_reminders"] = it }
            prefs[longPreferencesKey("last_synced_at")]?.let { result["last_synced_at"] = it }
            prefs[stringPreferencesKey("recent_searches")]?.let { result["recent_searches"] = it }
            prefs[booleanPreferencesKey("sqlcipher_migrated")]?.let { result["sqlcipher_migrated"] = it }
            prefs[stringPreferencesKey("custom_profile_image_b64")]?.let { result["custom_profile_image_b64"] = it }
            prefs[stringPreferencesKey("custom_display_name")]?.let { result["custom_display_name"] = it }
            prefs[booleanPreferencesKey("watch_circle_sharing")]?.let { result["watch_circle_sharing"] = it }
            prefs[stringPreferencesKey("hidden_from_circle_ids")]?.let { result["hidden_from_circle_ids"] = it }
            prefs[stringPreferencesKey("top_four_favorite_ids")]?.let { result["top_four_favorite_ids"] = it }
            prefs[stringPreferencesKey("custom_collections")]?.let { result["custom_collections"] = it }
            prefs[stringPreferencesKey("custom_invite_code")]?.let { result["custom_invite_code"] = it }
        } catch (e: Exception) {
            Log.w(TAG, "Failed reading legacy DataStore preferences: ${e.message}")
        }

        // If user already upgraded from Kotlin with data/settings, never re-show onboarding
        if (!result.containsKey("is_first_launch")) {
            result["is_first_launch"] = false
        }
        return result
    }

    private fun isPlaintextSqlite(file: File): Boolean {
        if (!file.exists() || file.length() < SQLITE_PLAINTEXT_HEADER.size) return false
        return try {
            val header = ByteArray(SQLITE_PLAINTEXT_HEADER.size)
            RandomAccessFile(file, "r").use { raf ->
                raf.readFully(header)
            }
            header.contentEquals(SQLITE_PLAINTEXT_HEADER)
        } catch (_: Exception) {
            false
        }
    }

    private fun readLegacyDatabase(
        dbFile: File,
        passphraseBytes: ByteArray?,
        outDramas: MutableList<Map<String, Any?>>,
        outShortcuts: MutableList<Map<String, Any?>>,
        outDetailCache: MutableList<Map<String, Any?>>
    ) {
        try {
            System.loadLibrary("sqlcipher")
        } catch (e: Throwable) {
            Log.w(TAG, "Failed loading libsqlcipher: ${e.message}")
        }

        val isPlaintext = isPlaintextSqlite(dbFile)
        val effectiveKey: ByteArray = if (isPlaintext) {
            ByteArray(0)
        } else {
            passphraseBytes ?: run {
                Log.w(TAG, "Encrypted legacy drama_db exists but no Tink DB key was recovered.")
                return
            }
        }

        var db: SQLiteDatabase? = null
        try {
            db = SQLiteDatabase.openDatabase(
                dbFile.absolutePath,
                effectiveKey,
                null,
                SQLiteDatabase.OPEN_READONLY,
                null,
                null
            )

            // 1. dramas
            runCatching {
                db.rawQuery("SELECT * FROM dramas", null).use { cursor ->
                    while (cursor.moveToNext()) {
                        outDramas.add(
                            hashMapOf(
                                "id" to cursor.optInt("id", 0),
                                "title" to cursor.optString("title", ""),
                                "overview" to cursor.optString("overview", ""),
                                "rating" to cursor.optDouble("rating", 0.0),
                                "posterPath" to cursor.optString("posterPath", ""),
                                "status" to cursor.optString("status", "Planned"),
                                "episodesWatched" to cursor.optInt("episodesWatched", 0),
                                "totalEpisodes" to cursor.optInt("totalEpisodes", 0),
                                "isDeleted" to (cursor.optInt("isDeleted", 0) != 0),
                                "addedAt" to cursor.optLong("addedAt", 0L),
                                "updatedAt" to cursor.optLong("updatedAt", 0L),
                                "completedAt" to cursor.optLong("completedAt", 0L),
                                "myRating" to cursor.optDouble("myRating", 0.0),
                                "notes" to cursor.optString("notes", ""),
                                "tags" to cursor.optString("tags", ""),
                                "genres" to cursor.optString("genres", ""),
                                "releaseYear" to cursor.optInt("releaseYear", 0),
                                "totalSeasons" to cursor.optInt("totalSeasons", 0),
                                "currentSeason" to cursor.optInt("currentSeason", 1),
                                "currentEpisode" to cursor.optInt("currentEpisode", 0),
                                "nextEpisodeAirDate" to cursor.optNullableString("nextEpisodeAirDate"),
                                "nextEpisodeNumber" to cursor.optInt("nextEpisodeNumber", 0),
                                "nextSeasonNumber" to cursor.optInt("nextSeasonNumber", 0),
                                "deletedAt" to cursor.optLong("deletedAt", 0L)
                            )
                        )
                    }
                }
            }

            // 2. shortcuts
            runCatching {
                db.rawQuery("SELECT * FROM shortcuts", null).use { cursor ->
                    while (cursor.moveToNext()) {
                        outShortcuts.add(
                            hashMapOf(
                                "id" to cursor.optInt("id", 0),
                                "title" to cursor.optString("title", ""),
                                "data" to cursor.optString("data", ""),
                                "type" to cursor.optString("type", "URL"),
                                "iconUrl" to cursor.optNullableString("iconUrl"),
                                "dramaId" to cursor.optInt("dramaId", 0)
                            )
                        )
                    }
                }
            }

            // 3. drama_details_cache
            runCatching {
                db.rawQuery("SELECT * FROM drama_details_cache", null).use { cursor ->
                    while (cursor.moveToNext()) {
                        outDetailCache.add(
                            hashMapOf(
                                "dramaId" to cursor.optInt("dramaId", 0),
                                "payloadJson" to cursor.optString("payloadJson", ""),
                                "cachedAt" to cursor.optLong("cachedAt", 0L)
                            )
                        )
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Unable to read legacy SQLCipher database: ${e.message}", e)
        } finally {
            runCatching { db?.close() }
        }
    }

    private fun Cursor.optInt(col: String, fallback: Int): Int {
        val idx = getColumnIndex(col)
        return if (idx >= 0 && !isNull(idx)) getInt(idx) else fallback
    }

    private fun Cursor.optLong(col: String, fallback: Long): Long {
        val idx = getColumnIndex(col)
        return if (idx >= 0 && !isNull(idx)) getLong(idx) else fallback
    }

    private fun Cursor.optDouble(col: String, fallback: Double): Double {
        val idx = getColumnIndex(col)
        return if (idx >= 0 && !isNull(idx)) getDouble(idx) else fallback
    }

    private fun Cursor.optString(col: String, fallback: String): String {
        val idx = getColumnIndex(col)
        return if (idx >= 0 && !isNull(idx)) getString(idx) else fallback
    }

    private fun Cursor.optNullableString(col: String): String? {
        val idx = getColumnIndex(col)
        return if (idx >= 0 && !isNull(idx)) getString(idx) else null
    }
}
