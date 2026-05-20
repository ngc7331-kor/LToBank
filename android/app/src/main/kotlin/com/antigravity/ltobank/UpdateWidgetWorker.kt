package com.antigravity.ltobank

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import androidx.work.Worker
import androidx.work.WorkerParameters
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import android.util.Log
import java.util.Calendar

class UpdateWidgetWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    private val client = OkHttpClient()

    override fun doWork(): Result {
        try {
            val context = applicationContext
            
            // 🛡️ [SECURITY] 빌드 시점에 주입된 안전한 리소스에서 키를 읽어옵니다. (깃허브 노출 0%)
            val proj = context.getString(R.string.ltobank_project_id)
            val key = context.getString(R.string.ltobank_api_key)
            
            if (proj.isEmpty() || key.isEmpty()) {
                Log.e("UpdateWidgetWorker", "API Key or Project ID is missing from resources!")
                return Result.failure()
            }

            // 📂 [우리집 세금 방식] HomeWidgetPreferences 창고 사용
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            
            val isLoggedIn = prefs.getBoolean("isLoggedIn", false)
            val userRole = (prefs.getString("userRole", "") ?: "").lowercase()
            
            if (!isLoggedIn || userRole.isEmpty()) return Result.success()

            // 🔒 보안 위반 방지: 허용되지 않은 역할(user 등)은 설정 정보를 완전 파괴하고 즉각 무출력 리턴
            if (userRole != "cw" && userRole != "dk" && userRole != "admin" && userRole != "parent") {
                prefs.edit().clear().apply()
                return Result.success()
            }

            val isAdmin = userRole.equals("admin", ignoreCase = true) || userRole.equals("parent", ignoreCase = true)

            // ⚙️ [인터넷 및 인증 유효성 체크] 수치 변동과 무관하게 항상 존재하는 환경설정 문서를 조회하여 연동 상태 검증
            val cUrl = "https://firestore.googleapis.com/v1/projects/$proj/databases/(default)/documents/config/widget?key=$key"
            val cRes = client.newCall(Request.Builder().url(cUrl).build()).execute()
            val isSyncSuccessful = cRes.isSuccessful

            // 1️⃣ 승인 대기 건수 계산
            val pUrl = "https://firestore.googleapis.com/v1/projects/$proj/databases/(default)/documents/approvals?key=$key"
            val res1 = client.newCall(Request.Builder().url(pUrl).build()).execute()
            
            var pCount = 0
            if (res1.isSuccessful) {
                val body = res1.body?.string() ?: ""
                if (body.contains("documents")) {
                    val json = JSONObject(body)
                    val docs = json.getJSONArray("documents")
                    for (i in 0 until docs.length()) {
                        val fields = docs.getJSONObject(i).optJSONObject("fields") ?: continue
                        val status = fields.optJSONObject("status")?.optString("stringValue") ?: ""
                        
                        if (status == "pending") {
                            if (isAdmin) {
                                pCount++
                            } else {
                                val requester = fields.optJSONObject("requester")?.optString("stringValue") ?: ""
                                if (requester == userRole) pCount++
                            }
                        }
                    }
                }
                prefs.edit().putInt("pendingCount", pCount).putString("workerStatus", "active").apply()
            } else if (res1.code == 404 && isSyncSuccessful) {
                // ℹ️ 다른 연동(config)은 정상이나 approvals만 404가 떴다면, 대기 요청 데이터가 비어있는 상태이므로 active로 처리
                prefs.edit().putInt("pendingCount", 0).putString("workerStatus", "active").apply()
            } else {
                // 실제 네트워크 끊김 또는 잘못된 인증 상태
                prefs.edit().putString("workerStatus", "vacation").apply()
            }

            // 2️⃣ 잔액 및 이자 수집
            val ids = arrayOf("cw", "dk")
            val format = java.text.NumberFormat.getCurrencyInstance(java.util.Locale.KOREA)
            format.maximumFractionDigits = 0

            for (id in ids) {
                val bUrl = "https://firestore.googleapis.com/v1/projects/$proj/databases/(default)/documents/banks/$id?key=$key"
                val bRes = client.newCall(Request.Builder().url(bUrl).build()).execute()
                if (bRes.isSuccessful) {
                    val fields = JSONObject(bRes.body?.string() ?: "{}").optJSONObject("fields") ?: continue
                    
                    val totalObj = fields.optJSONObject("totalBalance")
                    val total = totalObj?.optString("integerValue")?.toLongOrNull() 
                                ?: totalObj?.optString("doubleValue")?.toDoubleOrNull()?.toLong() 
                                ?: 0L
                                
                    val interestObj = fields.optJSONObject("interest")
                    val interest = interestObj?.optString("integerValue")?.toLongOrNull()
                                ?: interestObj?.optString("doubleValue")?.toDoubleOrNull()?.toLong()
                                ?: 0L
                    
                    if (id == "cw") {
                        prefs.edit().putString("cwTotal", format.format(total)).putString("cwInterest", "이자: " + format.format(interest)).apply()
                    } else {
                        prefs.edit().putString("dkTotal", format.format(total)).putString("dkInterest", "이자: " + format.format(interest)).apply()
                    }
                }
            }

            val timeStr = String.format("%02d:%02d", Calendar.getInstance().get(Calendar.HOUR_OF_DAY), Calendar.getInstance().get(Calendar.MINUTE))
            prefs.edit().putString("updateTime", timeStr).apply()

            val manager = AppWidgetManager.getInstance(context)
            val widgetIds = manager.getAppWidgetIds(ComponentName(context, LToBankWidget::class.java))
            for (widgetId in widgetIds) {
                LToBankWidget.updateAppWidget(context, manager, widgetId)
            }

            return Result.success()
        } catch (e: Exception) {
            Log.e("UpdateWidgetWorker", "Fatal error: ${e.message}")
            return Result.failure()
        }
    }
}
