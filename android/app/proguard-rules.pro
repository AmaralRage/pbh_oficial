# Spotify App Remote 0.8.0 uses GsonMapper by default (verified in ConnectionParams).
# Jackson serializers are optional and their dependencies are not bundled.
-dontwarn com.fasterxml.jackson.databind.deser.std.StdDeserializer
-dontwarn com.fasterxml.jackson.databind.ser.std.StdSerializer
-dontwarn com.spotify.base.annotations.NotNull

# Preserve protocol model fields read/written reflectively by Gson in release.
-keepattributes Signature,*Annotation*
-keep class com.spotify.protocol.types.** { *; }
