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

            // 100% Safe Accessors (from MyHomeTax Success Code)
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

            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            
            // Set 80% Transparency (Alpha 204)
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
                views.setTextViewText(R.id.txt_pending_count, pendingCount.toString())
                
                // 역할에 따른 텍스트 분기 (부모: 승인 대기, 자녀: 승인 요청중)
                val labelText = if (userRole == "parent") "승인 대기" else "승인 요청중"
                views.setTextViewText(R.id.txt_pending_label, labelText)
                
                // v48: 0건이더라도 명시적으로 보여주기 위해 항상 VISIBLE 유지
                views.setViewVisibility(R.id.layout_badge, View.VISIBLE)

                // v48: 역할별 레이아웃 최적화
                if (userRole == "parent") {
                    // 부모 모드: 세로 배치 (1 = vertical)
                    views.setInt(R.id.layout_accounts, "setOrientation", 1)
                    views.setViewVisibility(R.id.layout_left, View.VISIBLE)
                    views.setViewVisibility(R.id.layout_right, View.VISIBLE)
                    views.setViewVisibility(R.id.txt_left_name, View.VISIBLE)
                    views.setViewVisibility(R.id.txt_right_name, View.VISIBLE)
                } else {
                    // 자녀 모드: 가로 배치 (0 = horizontal)
                    views.setInt(R.id.layout_accounts, "setOrientation", 0)
                    if (userRole == "cw") {
                        views.setViewVisibility(R.id.layout_left, View.VISIBLE)
                        views.setViewVisibility(R.id.layout_right, View.GONE)
                        views.setViewVisibility(R.id.txt_left_name, View.GONE) // 자녀 모드: 이름 숨김
                    } else if (userRole == "dk") {
                        views.setViewVisibility(R.id.layout_left, View.GONE)
                        views.setViewVisibility(R.id.layout_right, View.VISIBLE)
                        views.setViewVisibility(R.id.txt_right_name, View.GONE) // 자녀 모드: 이름 숨김
                    }
                }

                views.setTextViewText(R.id.txt_left_amount, cwTotal)
                views.setTextViewText(R.id.txt_left_interest, cwInterest)
                views.setTextViewText(R.id.txt_right_amount, dkTotal)
                views.setTextViewText(R.id.txt_right_interest, dkInterest)
                views.setTextViewText(R.id.txt_last_updated, "최종 확인: $updateTime")
            }

            val launchIntent = es.antonborri.home_widget.HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
