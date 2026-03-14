# ─── Flutter Engine ─────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.**

# ─── Firebase / Google Play Services ────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ─── Hive ────────────────────────────────────────────────────────────────────
-keep class com.hive.** { *; }
-keep class io.hive.** { *; }
# Keep all Hive-generated TypeAdapters (annotated with @HiveType)
-keep @com.hive.annotation.HiveType class * { *; }
-keepclassmembers class * {
    @com.hive.annotation.HiveField *;
}

# ─── General Dart/Flutter reflection ─────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes Signature

# ─── Kotlin ──────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# ─── Mobile Scanner (CameraX / MLKit) ────────────────────────────────────────
-keep class com.google.mlkit.** { *; }
-keep class androidx.camera.** { *; }
-dontwarn com.google.mlkit.**

# ─── Connectivity Plus ───────────────────────────────────────────────────────
-dontwarn dev.fluttercommunity.plus.connectivity.**

# ─── Remove verbose logging in release ───────────────────────────────────────
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
