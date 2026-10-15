# flutter_local_notifications stores scheduled reminders as JSON through Gson,
# both when scheduling and when the alarm fires. R8 full mode strips the
# generic signature from Gson's anonymous TypeToken subclasses, which makes
# every scheduled reminder fail with "Missing type parameter" in release builds.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
