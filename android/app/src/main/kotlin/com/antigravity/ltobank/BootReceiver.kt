package com.antigravity.ltobank

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            
            // 🔋 폰이 켜지면 즉시 위젯 동기화 시작!
            Log.d("BootReceiver", "Boot completed! Syncing widget...")
            
            val workRequest = OneTimeWorkRequestBuilder<UpdateWidgetWorker>().build()
            WorkManager.getInstance(context).enqueue(workRequest)
        }
    }
}
