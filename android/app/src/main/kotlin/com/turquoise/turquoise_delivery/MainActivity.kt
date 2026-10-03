package com.turquoise.turquoise_delivery

import io.flutter.embedding.android.FlutterActivity
import android.content.pm.PackageManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mangaale/maps_configuration")
            .setMethodCallHandler { call, result ->
                if (call.method != "initialize") {
                    result.notImplemented()
                } else if (call.argument<Boolean>("enabled") != true) {
                    result.success(false)
                } else {
                    @Suppress("DEPRECATION")
                    val key = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                        .metaData?.getString("com.google.android.geo.API_KEY")?.trim().orEmpty()
                    result.success(key.isNotEmpty() && !key.startsWith("\${"))
                }
            }
    }
}
