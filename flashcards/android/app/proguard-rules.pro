# Google ML Kit on-device translation models are loaded dynamically at
# runtime, so their classes must survive R8 shrinking/obfuscation.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

-keep class com.dexterous.flutterlocalnotifications.** { *; }
