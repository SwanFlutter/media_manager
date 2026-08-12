# Flutter / Dart VM
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# media_manager plugin
-keep class com.example.media_manager.** { *; }

# AndroidX core
-keep class androidx.** { *; }
-dontwarn androidx.**

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings { <fields>; }

# Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory { *; }
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler { *; }
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# Suppress Skia / HWUI verbose debug logs in release
# (These are system-level; R8/ProGuard cannot directly silence them,
#  but enabling minify removes debug symbols that trigger verbose paths.)
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static boolean isLoggable(...);
}
