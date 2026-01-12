# Keep the entire eseeiot SDK from being renamed or removed
-keep class com.eseeiot.** { *; }
-keep interface com.eseeiot.** { *; }

# Keep the specific classes used via reflection in your plugin
-keep class com.eseeiot.device.DeviceManager { *; }
-keep class com.eseeiot.basemodule.** { *; }

# Prevent shrinking and obfuscation of native library interfaces (JNI)
-keepclasseswithmembernames class * {
    native <methods>;
}