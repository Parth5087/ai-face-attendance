# Flutter Wrapper & Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.common.** { *; }

# Google ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_**

# Google Play Services & Firebase Components (ML Kit Component Discovery)
-keep class com.google.firebase.components.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.firebase.components.**
-dontwarn com.google.android.gms.**

# TensorFlow Lite
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**
-keep class com.tflite.** { *; }

# Preserve attributes for reflection, generics, annotations
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
