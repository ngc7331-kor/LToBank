# Flutter 및 HomeWidget 보호 규칙
-keep class com.antigravity.ltobank.LToBankWidget { *; }
-keep public class * extends es.antonborri.home_widget.HomeWidgetProvider
-keep public class * extends android.appwidget.AppWidgetProvider

# RemoteViews 관련 클래스 보호
-keep class android.widget.RemoteViews { *; }
-keep class android.content.Context { *; }
-keep class android.content.Intent { *; }

# Kotlin 런타임 보호
-keep class kotlin.jvm.internal.** { *; }
