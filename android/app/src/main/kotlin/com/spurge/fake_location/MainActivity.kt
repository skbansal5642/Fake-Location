package com.spurge.fake_location

import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveConfig" -> {
                    try {
                        ConfigStore.saveJson(this, call.argument<String>("json")!!)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("bad_config", e.message, null)
                    }
                }
                "loadConfig" -> result.success(ConfigStore.loadJson(this))
                "status" -> result.success(MockLocationService.statusText)
                "currentSsid" -> result.success(SurroundingsReader(this).currentSsid())
                "start" -> {
                    MockLocationService.start(this)
                    result.success(null)
                }
                "stop" -> {
                    MockLocationService.stop(this)
                    result.success(null)
                }
                "isRunning" -> result.success(MockLocationService.isRunning)
                "isMockAppSelected" -> result.success(MockPermission.isGranted(this))
                "openDeveloperSettings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS))
                    result.success(null)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                "requestIgnoreBatteryOptimizations" -> {
                    startActivity(
                        Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val CHANNEL = "fake_location/mock"
    }
}
