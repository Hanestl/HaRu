package com.hanestl.flule34

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.provider.OpenableColumns
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createPrivateNotificationChannels()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "inspectFile" -> {
                    val rawUri = call.argument<String>("uri")
                    if (rawUri.isNullOrBlank()) {
                        result.error("INVALID_URI", "文件 URI 不能为空", null)
                    } else {
                        result.success(inspectFile(Uri.parse(rawUri)))
                    }
                }

                "deleteFile" -> {
                    val rawUri = call.argument<String>("uri")
                    if (rawUri.isNullOrBlank()) {
                        result.error("INVALID_URI", "文件 URI 不能为空", null)
                    } else {
                        result.success(deleteFile(Uri.parse(rawUri)))
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, MEDIA_VOLUME_CHANNEL).setMethodCallHandler { call, result ->
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            if (audioManager == null) {
                result.error("UNAVAILABLE", "无法获取系统媒体音量服务", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "current" -> result.success(normalizedMediaVolume(audioManager))
                "setNormalized" -> {
                    val value = call.argument<Double>("value")
                    if (value == null) {
                        result.error("INVALID_VALUE", "音量值不能为空", null)
                    } else {
                        try {
                            val maximum = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                            val target = (value.coerceIn(0.0, 1.0) * maximum).toInt()
                            audioManager.setStreamVolume(
                                AudioManager.STREAM_MUSIC,
                                target,
                                0,
                            )
                            result.success(null)
                        } catch (_: SecurityException) {
                            result.error("UNAVAILABLE", "系统拒绝调节媒体音量", null)
                        } catch (_: RuntimeException) {
                            result.error("UNAVAILABLE", "调节媒体音量失败", null)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, WEBVIEW_COOKIE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCookies" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.error("INVALID_URL", "URL 不能为空", null)
                    } else {
                        // 返回原始字符串，避免 Flutter 插件截断含 '=' 的 Cookie 值。
                        result.success(
                            android.webkit.CookieManager.getInstance().getCookie(url) ?: "",
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }

        val updaterChannel = MethodChannel(messenger, UPDATER_CHANNEL)
        updaterChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallPackages" -> result.success(canInstallPackages())
                "openInstallSettings" -> {
                    openInstallSettings()
                    result.success(null)
                }

                "installApk" -> installUpdateApk(call.argument<String>("path"), result)
                else -> result.notImplemented()
            }
        }
        InstallResultReceiver.listener = { status, message ->
            updaterChannel.invokeMethod(
                "installResult",
                mapOf("status" to status, "message" to message),
            )
        }
    }

    override fun onDestroy() {
        InstallResultReceiver.listener = null
        super.onDestroy()
    }

    private fun canInstallPackages(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return true
        }
        return packageManager.canRequestPackageInstalls()
    }

    private fun openInstallSettings() {
        val intents = listOf(
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            ),
            Intent(Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS),
        )
        for (intent in intents) {
            try {
                startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return
            } catch (_: ActivityNotFoundException) {
                // 尝试下一个系统设置入口。
            }
        }
    }

    private fun installUpdateApk(rawPath: String?, result: MethodChannel.Result) {
        if (rawPath.isNullOrBlank()) {
            result.error("INVALID_PATH", "安装包路径不能为空", null)
            return
        }
        val file = try {
            File(rawPath).canonicalFile
        } catch (_: RuntimeException) {
            result.error("INVALID_PATH", "安装包路径不合法", null)
            return
        }
        val updatesRoot = File(cacheDir, "updates").canonicalFile
        val allowed = file.path == updatesRoot.path ||
            file.path.startsWith(updatesRoot.path + File.separator)
        if (!allowed || !file.isFile) {
            result.error("INVALID_PATH", "安装包路径不合法或文件不存在", null)
            return
        }
        if (!canInstallPackages()) {
            result.success("permissionRequired")
            return
        }
        val mainHandler = Handler(Looper.getMainLooper())
        Log.i(UPDATER_LOG_TAG, "installUpdateApk: begin path=${file.path} size=${file.length()}")
        INSTALL_EXECUTOR.execute {
            try {
                val installer = packageManager.packageInstaller
                val params = PackageInstaller.SessionParams(
                    PackageInstaller.SessionParams.MODE_FULL_INSTALL,
                ).apply {
                    setAppPackageName(packageName)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        setInstallReason(PackageManager.INSTALL_REASON_USER)
                    }
                }
                val sessionId = installer.createSession(params)
                Log.i(UPDATER_LOG_TAG, "installUpdateApk: session=$sessionId created")
                installer.openSession(sessionId).use { session ->
                    file.inputStream().use { input ->
                        session.openWrite("haru-update.apk", 0, file.length()).use { output ->
                            input.copyTo(output)
                            session.fsync(output)
                        }
                    }
                    val statusIntent = Intent(applicationContext, InstallResultReceiver::class.java)
                        .setAction(ACTION_INSTALL_COMMIT)
                    val pendingIntent = PendingIntent.getBroadcast(
                        applicationContext,
                        sessionId,
                        statusIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
                    )
                    session.commit(pendingIntent.intentSender)
                }
                Log.i(UPDATER_LOG_TAG, "installUpdateApk: session=$sessionId committed")
                mainHandler.post { result.success("started") }
            } catch (_: SecurityException) {
                Log.w(UPDATER_LOG_TAG, "installUpdateApk: permission required")
                mainHandler.post { result.success("permissionRequired") }
            } catch (error: Exception) {
                Log.e(UPDATER_LOG_TAG, "installUpdateApk: failed", error)
                mainHandler.post {
                    result.error(
                        "INSTALL_FAILED",
                        error.message ?: "无法启动系统安装器，请稍后重试。",
                        null,
                    )
                }
            }
        }
    }

    private fun inspectFile(uri: Uri): Map<String, Any?> {
        if (uri.scheme == "file") {
            val file = uri.path?.let(::File)
            if (file == null) {
                return mapOf(
                    "exists" to false,
                    "readable" to false,
                    "name" to null,
                    "size" to null,
                )
            }
            val exists = file.exists() && file.isFile
            return mapOf(
                "exists" to exists,
                "readable" to (exists && file.canRead()),
                "name" to file.name,
                "size" to if (exists) file.length() else null,
            )
        }

        if (uri.scheme != "content") {
            return mapOf(
                "exists" to false,
                "readable" to false,
                "name" to null,
                "size" to null,
            )
        }

        return try {
            var name: String? = null
            var size: Long? = null
            var queryFoundFile = false
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    queryFoundFile = true
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (nameIndex >= 0 && !cursor.isNull(nameIndex)) {
                        name = cursor.getString(nameIndex)
                    }
                    if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                        size = cursor.getLong(sizeIndex)
                    }
                }
            }
            val readable = runCatching {
                contentResolver.openFileDescriptor(uri, "r")?.use { descriptor ->
                    if (size == null && descriptor.statSize >= 0L) {
                        size = descriptor.statSize
                    }
                    true
                } ?: false
            }.getOrDefault(false)
            mapOf(
                "exists" to (queryFoundFile || readable),
                "readable" to readable,
                "name" to name,
                "size" to size,
            )
        } catch (_: RuntimeException) {
            mapOf(
                "exists" to false,
                "readable" to false,
                "name" to null,
                "size" to null,
            )
        }
    }

    private fun deleteFile(uri: Uri): Boolean {
        if (uri.scheme == "file") {
            val file = uri.path?.let(::File)?.canonicalFile ?: return false
            val allowedRoots = listOfNotNull(
                filesDir,
                cacheDir,
                noBackupFilesDir,
                getExternalFilesDir(null),
                externalCacheDir,
            ).map { it.canonicalFile }
            val allowed = allowedRoots.any { root ->
                file.path == root.path || file.path.startsWith(root.path + File.separator)
            }
            if (!allowed) {
                return false
            }
            return !file.exists() || file.delete()
        }
        if (uri.scheme != "content") {
            return false
        }
        return try {
            val exists = inspectFile(uri)["exists"] == true
            !exists || contentResolver.delete(uri, null, null) > 0
        } catch (_: SecurityException) {
            false
        } catch (_: RuntimeException) {
            false
        }
    }

    private fun normalizedMediaVolume(audioManager: AudioManager): Double {
        val maximum = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (maximum <= 0) {
            return 0.0
        }
        return audioManager.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / maximum
    }

    private fun createPrivateNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val notificationManager = getSystemService(NotificationManager::class.java)
        val channels = listOf(
            Triple(
                DOWNLOAD_NOTIFICATION_CHANNEL,
                "后台任务",
                "用于保持后台任务可靠运行",
            ),
            Triple(
                MEDIA_NOTIFICATION_CHANNEL,
                "媒体播放",
                "用于保持后台播放可靠运行",
            ),
            Triple(
                PLAYER_SERVICE_NOTIFICATION_CHANNEL,
                "媒体播放服务",
                "用于保持后台播放服务可靠运行",
            ),
        )
        channels.forEach { (id, name, descriptionText) ->
            val channel = NotificationChannel(
                id,
                name,
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = descriptionText
                setSound(null, null)
                enableLights(false)
                enableVibration(false)
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_SECRET
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    companion object {
        const val STORAGE_CHANNEL = "com.hanestl.flule34/storage_access"
        const val MEDIA_VOLUME_CHANNEL = "com.hanestl.flule34/media_volume"
        const val WEBVIEW_COOKIE_CHANNEL = "com.hanestl.flule34/webview_cookie"
        const val UPDATER_CHANNEL = "com.hanestl.flule34/updater"
        const val DOWNLOAD_NOTIFICATION_CHANNEL = "background_downloader"
        const val MEDIA_NOTIFICATION_CHANNEL = "flule34_media_private"
        const val PLAYER_SERVICE_NOTIFICATION_CHANNEL = "better_player_channel"
        const val ACTION_INSTALL_COMMIT = "com.hanestl.flule34.UPDATE_INSTALL_COMMIT"
        const val UPDATER_LOG_TAG = "HaRuUpdater"
        val INSTALL_EXECUTOR = Executors.newSingleThreadExecutor()
    }
}
