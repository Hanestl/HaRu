# ADR-0021：后台下载的凭据副本与清理边界

- 状态：已接受
- 日期：2026-10-25
- 相关：ADR-0003, ADR-0004, ADR-0013, ADR-0017

## 背景

下载由 `background_downloader` 在平台侧执行，而不是在 Dart 侧用 `dio` 拉流。原因见 ADR-0017：需要在应用退到后台、甚至进程被系统回收后仍继续下载，并让任务出现在系统通知栏里。

问题在于媒体 URL 需要登录态：Rule34Video 与 Hanime 的视频文件都要求携带 Cookie（部分场景还要 Referer）。`DownloadRepository` 在入队前把鉴权头算好交给 `DownloadTask`（`lib/features/downloads/data/download_repository.dart` 的 `_headers()`）：

- 有视频对象时走 `_api.mediaHeadersFor(video)`
- 没有时走 `ContentSite.rule34video.mediaHeaders(cookie: await _api.sessionCookieHeader())`

而 `background_downloader` 为了支持后台恢复，会把任务对象序列化进自己的本地任务数据库。`background_downloader-9.5.7/lib/src/task.dart:123-132` 的 `Request.toJson()` 明确包含 `'headers': headers`，也就是说 **Cookie 会以明文形式落在应用私有目录里的任务记录中**。

这与"Cookie 只存在于 Android 安全存储"的既有说法（ADR-0003、PRIVACY.md）存在落差，必须显式记录，而不是当成实现细节。

## 决策

**接受这份明文副本，不为消除它而牺牲后台下载能力。**

排除的替代方案及原因：

1. **每次请求时由 Dart 动态注入头**：不可行。任务在后台执行，进程被回收后没有 Dart 侧可回调的时机；插件必须能脱离应用进程自行发请求。
2. **不把 Cookie 交给插件，改为短期签名 URL**：两个站点都不提供这种能力，我们只是客户端。
3. **加密任务记录**：插件没有提供可替换的存储后端，密钥同样要放在设备上，实际收益接近于零，却会引入自研插件分支的维护成本。
4. **只支持前台下载**：直接放弃 ADR-0017 的核心能力，不可接受。

## 缓解措施（已实施）

- `android/app/src/main/AndroidManifest.xml` 的 `allowBackup="false"`：系统云备份与设备迁移不会带走应用私有目录（含插件任务数据库）。
- `usesCleartextTraffic="false"` 与 `network_security_config.xml`：媒体请求只能走 HTTPS，避免 Cookie 在明文连接上泄露。
- 下载完成后，`BackgroundDownloadPlatformService._finalizeCompletedTask` 在把文件移入公共目录后调用 `_downloader.database.deleteRecordWithId(taskId)`，任务记录（含请求头）随之删除。这也是"先落库、再删记录"顺序的一部分：顺序反了会在删除后拿不到任务路径。
- 应用不集成广告、分析或第三方崩溃上报 SDK（见 PRIVACY.md），凭据不会随诊断信息外流；日志侧由 `lib/core/security/error_redaction.dart` 隐藏 Cookie 值，只保留 Cookie 名。

## 结果与残余风险

- 下载**进行中**、以及任务被系统中断但尚未重排的窗口内，插件任务数据库里存在明文 Cookie 副本。
- 该副本位于应用私有目录，未 root 的设备上其他应用无法读取；但**已 root 设备、或通过 adb backup / 调试工具**仍可能取到。
- 本决策没有做设备取证、备份验证或完整安全审计，因此**不能**据此声明"凭据没有其他暴露面"。

若将来 `background_downloader` 提供了可插拔的加密存储，或两个站点改为支持短期令牌，应重新评估本决策。
