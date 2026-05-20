package com.antigravity.ltobank

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.util.Log

class LToBankWidget : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == "com.antigravity.ltobank.UPDATE_WIDGET" || intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = android.content.ComponentName(context, LToBankWidget::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        internal fun updateAppWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            
            try {
                // 📂 [우리집 세금 방식] 공용 우체통 딱 하나만 사용 (flutter. 접두사 없음)
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

                // 🏷️ 열쇠 찾기 (우리집 세금과 동일하게 아주 단순화)
                val isLoggedIn = prefs.getBoolean("isLoggedIn", false)
                val userRole = (prefs.getString("userRole", "") ?: "").lowercase()
                
                if (!isLoggedIn || userRole.isEmpty()) {
                    views.setViewVisibility(R.id.txt_login_required, View.VISIBLE)
                    views.setViewVisibility(R.id.layout_data_container, View.GONE)
                    views.setViewVisibility(R.id.layout_badge, View.GONE) // 로그인 안됐으면 배지도 숨김
                } else {
                    views.setViewVisibility(R.id.txt_login_required, View.GONE)
                    views.setViewVisibility(R.id.layout_data_container, View.VISIBLE)

                    val isAdmin = userRole == "admin" || userRole == "parent"
                    val cwTotal = prefs.getString("cwTotal", "₩ 0") ?: "₩ 0"
                    val dkTotal = prefs.getString("dkTotal", "₩ 0") ?: "₩ 0"
                    val cwInterest = prefs.getString("cwInterest", "이자: ₩ 0") ?: "이자: ₩ 0"
                    val dkInterest = prefs.getString("dkInterest", "이자: ₩ 0") ?: "이자: ₩ 0"
                    val pendingCount = prefs.getInt("pendingCount", 0)
                    val updateTime = prefs.getString("updateTime", "--:--") ?: "--:--"
                    val workerStatus = prefs.getString("workerStatus", "active") ?: "active"

                    views.setTextViewText(R.id.txt_widget_title, "L.To Bank")
                    
                    // ✨ 배지 제어 (0건이면 절대 안보이게 강력 조치)
                    if (workerStatus == "vacation") {
                        views.setViewVisibility(R.id.layout_badge, View.VISIBLE)
                        views.setTextViewText(R.id.txt_pending_label, "자동 비서 휴가 중 🏖️")
                        views.setTextViewText(R.id.txt_pending_count, "")
                    } else if (pendingCount > 0) {
                        views.setViewVisibility(R.id.layout_badge, View.VISIBLE)
                        views.setTextViewText(R.id.txt_pending_label, if (isAdmin) "승인 대기: " else "승인 요청중: ")
                        views.setTextViewText(R.id.txt_pending_count, "${pendingCount}건")
                    } else {
                        // 0건일 때 GONE 처리 (사용자님 요청사항 100% 반영)
                        views.setViewVisibility(R.id.layout_badge, View.GONE)
                    }

                    // ✨ 레이아웃 제어 (부모/자녀 맞춤형)
                    if (isAdmin) {
                        views.setViewVisibility(R.id.layout_left, View.VISIBLE)
                        views.setViewVisibility(R.id.layout_right, View.VISIBLE)
                        views.setViewVisibility(R.id.txt_left_name, View.VISIBLE)
                        views.setViewVisibility(R.id.txt_right_name, View.VISIBLE)
                        // 🏷️ 이자액 숫자 앞에 '이자:' 접두사가 정상 노출되도록 수정
                        views.setTextViewText(R.id.txt_left_amount, cwTotal)
                        views.setTextViewText(R.id.txt_left_interest, cwInterest)
                        views.setTextViewText(R.id.txt_right_amount, dkTotal)
                        views.setTextViewText(R.id.txt_right_interest, dkInterest)
                    } else {
                        if (userRole == "cw") {
                            views.setViewVisibility(R.id.layout_left, View.VISIBLE)
                            views.setViewVisibility(R.id.layout_right, View.GONE)
                            views.setViewVisibility(R.id.txt_left_name, View.GONE)
                            views.setTextViewText(R.id.txt_left_amount, "저금액: $cwTotal")
                            views.setTextViewText(R.id.txt_left_interest, cwInterest)
                        } else if (userRole == "dk") {
                            views.setViewVisibility(R.id.layout_left, View.GONE)
                            views.setViewVisibility(R.id.layout_right, View.VISIBLE)
                            views.setViewVisibility(R.id.txt_right_name, View.GONE)
                            views.setTextViewText(R.id.txt_right_amount, "저금액: $dkTotal")
                            views.setTextViewText(R.id.txt_right_interest, dkInterest)
                        } else {
                            // 🔒 보안 위반 원천 방지: 권한이 불명확하거나 누락된 경우 양쪽 계좌 정보를 모두 차단/숨김 처리
                            views.setViewVisibility(R.id.layout_left, View.GONE)
                            views.setViewVisibility(R.id.layout_right, View.GONE)
                        }
                    }
                    views.setTextViewText(R.id.txt_last_updated, "최종 확인: $updateTime")
                }

                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, intent, 
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            } catch (e: Exception) {
                Log.e("LToBankWidget", "Widget update error: ${e.message}")
            }

            manager.updateAppWidget(widgetId, views)
        }
    }
}
