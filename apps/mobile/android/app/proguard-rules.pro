# Flutter-specific ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Sentry — keep for proper stack traces
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# Keep annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
