# ── Lepu BLE SDK ──────────────────────────────────────────────
# Keep the entire Lepu SDK and its transitive deps from being stripped by R8
-keep class com.lepu.** { *; }
-dontwarn com.lepu.**

# Apache Commons IO (referenced transitively by Lepu SDK)
-keep class org.apache.commons.io.** { *; }
-dontwarn org.apache.commons.io.**

# Nordic Semiconductor BLE library
-keep class no.nordicsemi.android.** { *; }
-dontwarn no.nordicsemi.android.**

# LiveEventBus
-keep class com.jeremyliao.liveeventbus.** { *; }
-dontwarn com.jeremyliao.liveeventbus.**

# Stream Log (used by Lepu SDK)
-keep class io.getstream.log.** { *; }
-dontwarn io.getstream.log.**

# Keep obfuscated SDK references intact
-keep class doag.** { *; }
-dontwarn doag.**
