# Strip all android.util.Log calls in release builds (prevents log leakage & clears MobSF android_logging)
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
    public static int wtf(...);
}

# Eliminate unreachable API-29 biometric fake CBC CryptoObject (Moglog uses biometricOnly=false / DEVICE_CREDENTIAL)
-assumenosideeffects class androidx.biometric.CryptoObjectUtils {
    static androidx.biometric.BiometricPrompt$CryptoObject createFakeCryptoObject() return null;
}

# Keep Room & WorkManager generated database classes (prevents R8 full-mode stripping of WorkDatabase_Impl.<init>)
-keep class * extends androidx.room.RoomDatabase {
    public <init>(...);
    <init>(...);
}
-keepclassmembers class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keepclassmembers class * extends androidx.work.Worker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keepclassmembers class * extends androidx.work.CoroutineWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# Keep AndroidX Startup initializers
-keep class * extends androidx.startup.Initializer {
    public <init>(...);
    <init>(...);
}

# Keep SQLCipher native JNI hooks
-keep class net.sqlcipher.** { *; }
-keep class net.zetetic.** { *; }
-dontwarn net.zetetic.**
-dontwarn net.sqlcipher.**

# Keep Google Sign-In, Credential Manager, Firebase Auth & App Check JNI/reflective entrypoints
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.appcheck.** { *; }
-keep class androidx.credentials.** { *; }
-keep interface androidx.credentials.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep interface com.google.android.libraries.identity.googleid.** { *; }
-dontwarn androidx.credentials.**
-dontwarn com.google.android.libraries.identity.googleid.**
-dontwarn com.google.firebase.appcheck.**

# Keep Google Tink & DataStore reflective primitives
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
-keep class androidx.datastore.** { *; }

# Keep Flutter MainActivity & WorkManager Worker entrypoints (allow internal helpers to be obfuscated)
-keep class com.skech.moglog.MainActivity { *; }
-keep class com.skech.moglog.EpisodeReminderWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
