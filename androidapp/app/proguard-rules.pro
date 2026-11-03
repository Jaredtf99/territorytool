# kotlinx.serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class kotlinx.serialization.json.** { kotlinx.serialization.KSerializer serializer(...); }
-keep,includedescriptorclasses class com.jared.territorytool.**$$serializer { *; }
-keepclassmembers class com.jared.territorytool.** { *** Companion; }
-keepclasseswithmembers class com.jared.territorytool.** { kotlinx.serialization.KSerializer serializer(...); }

# MapLibre
-keep class org.maplibre.** { *; }
-dontwarn org.maplibre.**
