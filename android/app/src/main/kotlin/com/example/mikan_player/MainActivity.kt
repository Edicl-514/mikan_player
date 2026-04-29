package com.edicl.mikan_player

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val downloadServiceChannel = "mikan_player/download_service"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Initialize the Android certificate verifier before any Rust networking starts.
        if (!RustlsVerifier.init(applicationContext)) {
            Log.e("MikanPlayer", "Failed to initialize rustls-platform-verifier")
        }

        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            downloadServiceChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    requestNotificationPermissionIfNeeded()
                    val intent = Intent(this, DownloadForegroundService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stop" -> {
                    val intent = Intent(this, DownloadForegroundService::class.java).apply {
                        action = DownloadForegroundService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            1001,
        )
    }
}
