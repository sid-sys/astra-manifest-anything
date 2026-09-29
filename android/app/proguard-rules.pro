# Keep rules for the release build's R8 pass.
#
# R8 is on because Play measures how much of the app is obfuscated and warns
# below 25%; Astra sat at 2%, which is what "minify off" looks like from the
# outside. Turning it on shrinks and renames the Java/Kotlin half of the app —
# the Dart half is already native code in libapp.so and is not affected either
# way.
#
# Everything below exists because R8 decides what is unused by looking at what
# is *called*, and it cannot see a call that happens through reflection, from
# native code, or from the Android system by class name. Those are exactly the
# routes Firebase, the audio service, and the billing client use, so each block
# names the things that would otherwise be renamed or deleted and then fail at
# runtime — on a release build only, which is the worst place to find out.

# ---------------------------------------------------------------- Flutter
# The engine looks these up from C++ by name.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.embedding.**

# ---------------------------------------------------------------- Firebase
# Model classes are read and written by reflection, and the whole Firestore
# serializer works on field names — renaming a field changes the document.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore and Cloud Functions ride on gRPC and protobuf, both of which
# resolve types by name at runtime.
-keep class io.grpc.** { *; }
-keep class com.google.protobuf.** { *; }
-dontwarn io.grpc.**
-dontwarn com.google.protobuf.**
-dontwarn javax.naming.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# ---------------------------------------------------------- Google Sign-In
# Credential Manager, and the only thing standing between the app and the
# sign-in bug that took months to find. Not worth risking to save a few KB.
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class androidx.credentials.** { *; }
-dontwarn androidx.credentials.**

# --------------------------------------------------------------- Billing
# The Play Billing library is called through generated stubs and reads its own
# response classes reflectively. A renamed field here is a purchase that cannot
# be parsed — the one failure mode in this app that costs a user money.
-keep class com.android.billingclient.** { *; }
-keep class com.android.vending.billing.** { *; }
-dontwarn com.android.billingclient.**

# ----------------------------------------------------------------- Audio
# `audio_service` runs in a foreground service that Android starts by class
# name out of the manifest, so the name has to survive.
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class androidx.media.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn com.ryanheise.**
-dontwarn androidx.media3.**

# --------------------------------------------------- Local notifications
# Scheduled notifications are restored after a reboot by a receiver Android
# looks up by name, and the plugin serialises pending notifications with Gson.
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-dontwarn com.dexterous.**

# Gson keeps generic types through reflection.
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# ------------------------------------------------------------ Play Core
# Referenced by the Flutter engine's deferred-components support, which this
# app does not use. Without this the build fails on missing classes rather
# than on anything real.
-dontwarn com.google.android.play.core.**

# ------------------------------------------------------------- Kotlin
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ------------------------------------------------------- Crash reports
# Keeps line numbers in stack traces so a crash from the Play Console is
# readable. Without these, every trace is a list of `a.b.c(Unknown Source)`.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
