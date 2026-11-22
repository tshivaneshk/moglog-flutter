# Keep Room & WorkManager generated database classes (prevents R8 full-mode stripping of WorkDatabase_Impl.<init>)
-keep class * extends androidx.room.RoomDatabase {
    public <init>(...);
    <init>(...);
}
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Entity class * { *; }
-keep @androidx.room.Dao class * { *; }
-keep class androidx.work.** { *; }
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

# Keep Google Sign-In, Credential Manager, Firebase Auth & App Check
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

# Keep Google Tink & DataStore (used by one-time Kotlin v3.0 -> Flutter v3.1 migrator)
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
-keep class androidx.datastore.** { *; }

# Keep Flutter MainActivity, Workers & Migration bridge
-keep class com.skech.moglog.** { *; }
-keep class dev.fluttercommunity.workmanager.** { *; }
