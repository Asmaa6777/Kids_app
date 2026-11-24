package com.familycall.family_call

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Exposes Android "Lock Task mode" (screen pinning) to Dart.
 *
 * startLockTask() pins the app: Home and Recents stop working until it is
 * unpinned. Without device-owner provisioning, Android shows the user a
 * one-time "Pin this app?" confirmation, which the parent accepts.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "familycall/kiosk")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "start" -> { startLockTask(); result.success(true) }
                        "stop" -> { stopLockTask(); result.success(true) }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("KIOSK", e.message, null)
                }
            }
    }
}
