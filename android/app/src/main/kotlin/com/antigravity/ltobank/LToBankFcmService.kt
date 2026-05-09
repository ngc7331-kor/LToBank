package com.antigravity.ltobank

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import android.util.Log

class LToBankFcmService : FirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        
        // 🚨 아이들의 신호가 감지되면 즉시 위젯 119 요원 출동!
        Log.d("LToBankFcm", "Signal received! Updating widget...")
        
        val workRequest = OneTimeWorkRequestBuilder<UpdateWidgetWorker>().build()
        WorkManager.getInstance(applicationContext).enqueue(workRequest)
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // 새로운 토큰이 생성되면 로그에 남깁니다 (플러터에서 처리됨)
        Log.d("LToBankFcm", "New token: $token")
    }
}
