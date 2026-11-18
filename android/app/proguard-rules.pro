# R8 rules for Bloom release builds. Flutter's Gradle plugin adds its own rules
# for the engine and plugin registrant.

# flutter_local_notifications stores scheduled notifications as JSON with Gson.
# These are the Gson rules its README asks apps to add
# (https://github.com/google/gson/blob/main/examples/android-proguard-example/proguard.cfg).
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# The plugin's own model classes are (de)serialized by reflection.
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Flutter references Play Core for deferred components, which Bloom doesn't use.
-dontwarn com.google.android.play.core.**
