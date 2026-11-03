package dev.pokercredits.poker_credits

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps the app's process alive while this phone hosts a game, so the embedded server keeps
 * answering the other players when the host switches app or locks the screen. It holds no game
 * state: the server runs in the Flutter engine's process and this service only stops Android from
 * freezing that process. The notification is required by Android and says what is running.
 */
class HostService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val room = intent?.getStringExtra(EXTRA_ROOM).orEmpty()
        ensureChannel()
        val notification = buildNotification(room)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 14 requires the type to be declared and passed; it matches the manifest.
            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            } else {
                0
            }
            startForeground(NOTIFICATION_ID, notification, type)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        // Not sticky: after the process is killed there is no server left to keep alive. The
        // next launch offers to resume the room from the journal.
        return START_NOT_STICKY
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(CHANNEL_ID, "Hosting a game", NotificationManager.IMPORTANCE_LOW)
        channel.description = "Shown while this phone hosts a poker game for the other players."
        channel.setShowBadge(false)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(room: String): Notification {
        val open = packageManager.getLaunchIntentForPackage(packageName)
        val pending = PendingIntent.getActivity(
            this, 0, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(R.drawable.ic_stat_host)
            .setContentTitle("Hosting room $room")
            .setContentText("Players are connected to this phone. Tap to open the table.")
            .setContentIntent(pending)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    companion object {
        const val EXTRA_ROOM = "roomCode"
        private const val CHANNEL_ID = "hosting"
        private const val NOTIFICATION_ID = 7878

        fun start(context: Context, room: String) {
            val intent = Intent(context, HostService::class.java).putExtra(EXTRA_ROOM, room)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                // API 24-25 have no startForegroundService; startService plus startForeground works.
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, HostService::class.java))
        }
    }
}
