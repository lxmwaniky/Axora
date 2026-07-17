package com.lxmwaniky.axora

import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val DISK_CHANNEL = "com.lxmwaniky.axora/disk_space"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Disk space channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DISK_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getFreeDiskSpace") {
                try {
                    val path = filesDir.absolutePath
                    val stat = StatFs(path)
                    val bytesAvailable = stat.blockSizeLong * stat.availableBlocksLong
                    result.success(bytesAvailable)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "Failed to get free disk space", e.localizedMessage)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
