package com.hanestl.flule34

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.util.Log
import androidx.core.content.IntentCompat

/**
 * 接收 PackageInstaller 会话的安装结果，并转发给 Flutter 侧展示失败原因。
 *
 * `STATUS_PENDING_USER_ACTION` 表示系统需要用户确认安装：本接收器负责拉起
 * 系统安装确认页；其余状态（取消、签名冲突、存储不足等）转发给 Flutter。
 * 安装成功时本应用进程会被系统终止，因此成功状态一般不会回调到这里。
 */
class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != MainActivity.ACTION_INSTALL_COMMIT) {
            return
        }
        val status = intent.getIntExtra(
            PackageInstaller.EXTRA_STATUS,
            PackageInstaller.STATUS_FAILURE,
        )
        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
        Log.i(MainActivity.UPDATER_LOG_TAG, "install result: status=$status message=$message")
        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            val confirmIntent = IntentCompat.getParcelableExtra(
                intent,
                Intent.EXTRA_INTENT,
                Intent::class.java,
            )
            if (confirmIntent == null) {
                listener?.invoke(PackageInstaller.STATUS_FAILURE, "系统未返回安装确认页")
                return
            }
            confirmIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                context.startActivity(confirmIntent)
            } catch (error: RuntimeException) {
                Log.e(MainActivity.UPDATER_LOG_TAG, "launch installer failed", error)
                listener?.invoke(
                    PackageInstaller.STATUS_FAILURE,
                    error.message ?: "无法打开系统安装确认页",
                )
            }
            return
        }
        listener?.invoke(status, message)
    }

    companion object {
        /** 由 MainActivity 在 configureFlutterEngine 中绑定，onDestroy 时解绑。 */
        @Volatile
        var listener: ((Int, String?) -> Unit)? = null
    }
}
