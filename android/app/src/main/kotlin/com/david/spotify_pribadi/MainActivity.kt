package com.david.spotify_pribadi

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Host Activity aplikasi.
 *
 * Selain duties audio service, Activity ini menyediakan jembatan native untuk
 * izin "Akses semua file" (`MANAGE_EXTERNAL_STORAGE`) yang dibutuhkan untuk
 * menulis berkas audio ke folder publik pada Android 11+.
 *
 * Catatan: `FlutterActivity` mewarisi `android.app.Activity` (bukan
 * `ComponentActivity`), sehingga Activity Result API modern
 * (`registerForActivityResult`) tidak tersedia. Karena itu hasil permintaan
 * izin ditangkap melalui `startActivityForResult` + `onActivityResult`.
 */
class MainActivity : AudioServiceActivity() {
    private val channelName = "com.david.spotify_pribadi/storage"
    private val requestCodeAllFiles = 9137
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(hasAllFilesAccess())
                    "requestPermission" -> requestAllFilesAccess(result)
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        if (url != null) {
                            try {
                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("OPEN_FAILED", e.message, null)
                            }
                        } else {
                            result.error("INVALID_URL", "URL tidak boleh kosong", null)
                        }
                    }
                    "openBatterySettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            val intent = Intent(Settings.ACTION_SETTINGS)
                            startActivity(intent)
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == requestCodeAllFiles) {
            val granted = hasAllFilesAccess()
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun hasAllFilesAccess(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return true
        return Environment.isExternalStorageManager()
    }

    private fun requestAllFilesAccess(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.success(true)
            return
        }
        if (hasAllFilesAccess()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("IN_PROGRESS", "Permintaan izin sedang berjalan", null)
            return
        }

        pendingPermissionResult = result
        val intent = Intent(
            Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
            Uri.parse("package:$packageName")
        )
        try {
            startActivityForResult(intent, requestCodeAllFiles)
        } catch (e: Exception) {
            pendingPermissionResult = null
            result.success(false)
        }
    }
}
