package dev.pokercredits.poker_credits

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    askForNotifications()
                    try {
                        HostService.start(this, call.argument<String>("roomCode").orEmpty())
                        result.success(null)
                    } catch (error: RuntimeException) {
                        // For example the system refused a background start; the game still runs
                        // while the app is on screen.
                        result.error("start_failed", error.message, null)
                    }
                }
                "stop" -> {
                    HostService.stop(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Android 13+ hides the service notification until the user allows notifications. The service
     * runs either way; this only asks once so the host can see why the phone stays awake.
     */
    private fun askForNotifications() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 0)
    }

    private companion object {
        const val CHANNEL = "dev.pokercredits/host_service"
    }
}
