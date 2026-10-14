package com.example.nus_nus

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createExpenseNotificationChannel()
    }

    /**
     * High-importance channel so "new split" pushes pop up as heads-up
     * notifications. The id must match the channelId sent by the
     * onExpenseCreated Cloud Function and the default_notification_channel_id
     * meta-data in AndroidManifest.xml. Creating a channel that already
     * exists is a no-op.
     */
    private fun createExpenseNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "expenses",
            "New splits",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Alerts when someone adds an expense that includes you"
        }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }
}
