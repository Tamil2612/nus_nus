# MediaPipe rules to ignore missing classes that are not needed at runtime
-dontwarn com.google.mediapipe.**
-dontwarn com.google.auto.value.extension.memoized.**

# Keep MediaPipe and related classes
-keep class com.google.mediapipe.** { *; }
-keep class com.google.auto.value.extension.memoized.** { *; }

# General Flutter ProGuard rules
-dontwarn com.google.android.play.core.**
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
