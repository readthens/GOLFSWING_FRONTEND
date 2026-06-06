package com.readthens.swinglensai.swinglens_ai

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.readthens.swinglensai/capture",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCaptureCapabilities" -> result.success(
                    mapOf("highFpsCaptureAvailable" to false),
                )
                else -> result.notImplemented()
            }
        }
    }
}
