# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# SharedPreferences plugin (prevents R8 NoSuchMethodError stripping)
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keepclassmembers class io.flutter.plugins.sharedpreferences.** { *; }

# Google Sign-In & Play Services
-keep class com.google.android.gms.auth.api.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Socket.IO & OkHttp
-keep class io.socket.** { *; }
-keep class okhttp3.** { *; }

# Kotlin Coroutines
-keep class kotlinx.coroutines.** { *; }

# Play Core deferred components suppression (handled by Flutter)
-dontwarn com.google.android.play.core.**

