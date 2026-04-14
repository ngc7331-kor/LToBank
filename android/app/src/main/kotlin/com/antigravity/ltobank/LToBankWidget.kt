package com.antigravity.ltobank

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.view.View
import android.content.Intent
import android.app.PendingIntent
import com.antigravity.ltobank.MainActivity
import android.util.Log

class LToBankWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private const val KEY_IS_LOGGED_IN = "isLoggedIn"
        private const val KEY_USER_ROLE = "userRole"
        private const val KEY_CW_TOTAL = "cwTotal"
        private const val KEY_DK_TOTAL = "dkTotal"
        private const val KEY_CW_INTEREST = "cwInterest"
        private const val KEY_DK_INTEREST = "dkInterest"
        private const val KEY_PENDING = "pendingCount"
        private const val KEY_UPDATE_TIME = "updateTime"

        internal fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            
            try {
                val prefsFiles = arrayOf("HomeWidgetPreferences", "com.antigravity.ltobank_preferences", "FlutterSharedPreferences")
                var finalSharedPrefs: SharedPreferences? = null
                
                for (fileName in prefsFiles) {
                    val sp = context.getSharedPreferences(fileName, Context.MODE_PRIVATE)
                    if (sp.contains("flutter.$KEY_IS_LOGGED_IN") || sp.contains(KEY_IS_LOGGED_IN)) {
                        finalSharedPrefs = sp
                        break
                    }
                }
                
                val sharedPrefs = finalSharedPrefs ?: context.getSharedPreferences(prefsFiles[0], Context.MODE_PRIVATE)

                val getSafeBool = { key: String, def: Boolean ->
                    val finalKey = if (sharedPrefs.contains("flutter.$key")) "flutter.$key" else key
                    var result = def
                    if (sharedPrefs.contains(finalKey)) {
                        try { result = sharedPrefs.getBoolean(finalKey, def) } 
                        catch (e: Exception) {
                            try { result = sharedPrefs.getString(finalKey, def.toString())?.toBoolean() ?: def } catch (e2: Exception) { }
                        }
                    }
                    result
                }

                val getSafeString = { key: String, def: String ->
                    val finalKey = if (sharedPrefs.contains("flutter.$key")) "flutter.$key" else key
                    sharedPrefs.getString(finalKey, def) ?: def
                }

                val getSafeInt = { key: String, def: Int ->
                    val finalKey = if (sharedPrefs.contains("flutter.$key")) "flutter.$key" else key
                    var result = def
                    if (sharedPrefs.contains(finalKey)) {
                        try { result = sharedPrefs.getInt(finalKey, def) } 
                        catch (e: Exception) {
                            try { result = (sharedPrefs.getString(finalKey, def.toString())?.toDouble()?.toInt()) ?: def } catch (e2: Exception) { }
                        }
                    }
                    result
                }

                // Set 80% Transparency
                views.setInt(R.id.widget_bg, "setImageAlpha", 204)

                val isLoggedIn = getSafeBool(KEY_IS_LOGGED_IN, false)
                
                if (!isLoggedIn) {
                    views.setViewVisibility(R.id.txt_login_required, View.VISIBLE)
                    views.setViewVisibility(R.id.layout_data_container, View.GONE)
                } else {
                    views.setViewVisibility(R.id.txt_login_required, View.GONE)
                    views.setViewVisibility(R.id.layout_data_container, View.VISIBLE)

                    val userRole = getSafeString(KEY_USER_ROLE, "parent")
                    val cwTotal = getSafeString(KEY_CW_TOTAL, "₩ 0")
                    val dkTotal = getSafeString(KEY_DK_TOTAL, "₩ 0")
                    val cwInterest = getSafeString(KEY_CW_INTEREST, "이자: ₩ 0")
                    val dkInterest = getSafeString(KEY_DK_INTEREST, "이자: ₩ 0")
                    val pendingCount = getSafeInt(KEY_PENDING, 0)
                    val updateTime = getSafeString(KEY_UPDATE_TIME, "--:--")

                    views.setTextViewText(R.id.txt_widget_title, "L.To Bank")
                    
                    // 🏷️ 역할별 문구 차별화
                    if (userRole == "parent") {
                        views.setTextViewText(R.id.txt_pending_label, "승인대기:")
                        views.setViewVisibility(R.id.layout_left, View.VISIBLE)
                        views.setViewVisibility(R.id.layout_right, View.VISIBLE)
                        views.setViewVisibility(R.id.txt_left_name, View.VISIBLE)
                        views.setViewVisibility(R.id.txt_right_name, View.VISIBLE)
                    } else {
                        views.setTextViewText(R.id.txt_pending_label, "승인 요청중:")
                        if (userRole == "cw") {
                            views.setViewVisibility(R.id.layout_left, View.VISIBLE)
                            views.setViewVisibility(R.id.layout_right, View.GONE)
                            views.setViewVisibility(R.id.txt_left_name, View.GONE)
                        } else if (userRole == "dk") {
                            views.setViewVisibility(R.id.layout_left, View.GONE)
                            views.setViewVisibility(R.id.layout_right, View.VISIBLE)
                            views.setViewVisibility(R.id.txt_right_name, View.GONE)
                        }
                    }
                    
                    views.setTextViewText(R.id.txt_pending_count, "${pendingCount}건")
                    views.setViewVisibility(R.id.layout_badge, View.VISIBLE)

                    // 이자 텍스트 최적화 (Dart에서 '이자: ₩ n'으로 오므로 괄호 처리 등 검토)
                    // 만약 Dart에서 온 값이 이미 '이자: ₩ n' 형태라면 그대로 표시하거나 깔끔하게 가공
                    val cleanCwInterest = cwInterest.replace("이자: ", "")
                    val cleanDkInterest = dkInterest.replace("이자: ", "")
                    
                    views.setTextViewText(R.id.txt_left_amount, cwTotal)
                    views.setTextViewText(R.id.txt_left_interest, "($cleanCwInterest)")
                    views.setTextViewText(R.id.txt_right_amount, dkTotal)
                    views.setTextViewText(R.id.txt_right_interest, "($cleanDkInterest)")
                    views.setTextViewText(R.id.txt_last_updated, "최종 확인: $updateTime")
                }

                // 🚀 표준 PendingIntent 적용
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, intent, 
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            } catch (e: Exception) {
                Log.e("LToBankWidget", "Widget Update Error: ${e.message}")
                views.setViewVisibility(R.id.txt_login_required, View.VISIBLE)
                views.setViewVisibility(R.id.layout_data_container, View.GONE)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
