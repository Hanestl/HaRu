# better_player_plus 本地补丁说明

本目录是 [better_player_plus](https://pub.dev/packages/better_player_plus) 的 vendored 副本（`pubspec.yaml:54-55`
以 `better_player_plus:
  path: third_party/better_player_plus` 直接引用，不是 `dependency_overrides`）。之所以复制进仓库，
是因为播放器有若干上游未合并的稳定性修复，且需要与 App 的播放/下载生命周期行为对齐。

## 上游基线

| 项 | 值 |
| --- | --- |
| 包名 | `better_player_plus` |
| 版本 | `1.3.4`（与本目录 `pubspec.yaml` 的 `version:` 一致） |
| 来源 | `https://pub.dev/api/archives/better_player_plus-1.3.4.tar.gz` |
| 归档 SHA-256 | `a9eee21c82d51c54cf346ceed2ddb44e305caf18d6321df2c24d6a9b720fff29` |
| 归档大小 | 194764 字节 |

相对上游归档，本目录**删除了**以下非运行时内容（不影响 Android/iOS 构建）：

- `example/`、`test/` —— 上游示例与自身测试，vendored 副本不需要。
- `analysis_options.yaml` —— 上游自身的 lint 配置；删掉后本目录继承仓库根的 `analysis_options.yaml`。
- `ios/Assets/` —— 上游归档里是**空目录**，删除无影响。

`pubspec.yaml`、`CHANGELOG.md` 与上游逐字节一致（`diff` 无差异）。

## 补丁清单

共 3 个文件包含实质改动。`lib/src/video_player/video_player.dart` 里另有大量**纯 `dart format` 重排**
（历史上被 `dart format` 整体重排过一次，可能是 IDE 保存时触发），这些不计入补丁，只在下文 P-3 第 4 点说明。
注意 CI 的 format 门禁命令是 `dart format --output=none --set-exit-if-changed lib test tool`，**不包含** `third_party`，
所以这些重排不会被门禁拦住，但升级上游时它们会让 `diff` 显得比实际改动大得多——按 P-3 第 4 点识别即可。

### P-1 `android/.../BetterPlayer.kt`：dispose 后禁止访问 ExoPlayer

**问题**：上游在 `dispose()` 之后仍然可以调用 `position` / `absolutePosition` / `sendBufferingUpdate`。
Flutter 侧 `dispose()` 是异步的，平台侧 `EventChannel` 与 `MethodChannel` 的调用可能晚于 `release()`，
此时 `exoPlayer` 已释放，Kotlin 侧会抛 `IllegalStateException` / NPE，表现为播放器退出时偶发崩溃或
`PlatformException` 刷屏。

**补丁**：

```kotlin
private var disposed = false

fun sendBufferingUpdate(isFromBufferingStart: Boolean) {
    if (disposed) return
    // ...
}

val position: Long
    get() = if (disposed) 0L else exoPlayer?.currentPosition ?: 0L

val absolutePosition: Long
    get() {
        if (disposed) return 0L
        // ...
    }

fun dispose() {
    if (disposed) return
    disposed = true
    // ...
}
```

`dispose()` 也变成幂等（重复调用直接返回）。另有一处 Tab 缩进被改为空格，无行为影响。

### P-2 `android/.../BetterPlayerPlugin.kt`：平台调用异常兜底 + POSITION 顺序修正

**问题 A**：上游 `onMethodCall` 未包 try/catch。ExoPlayer 内部抛出的 `Throwable` 会穿透到 Flutter 引擎的
平台通道实现，被当作未处理异常记录，Dart 侧 `MethodChannel.invokeMethod` 的 Future 永远不完成（悬挂）。

**问题 B**：上游 `POSITION_METHOD` 先 `result.success(player.position)` 再 `sendBufferingUpdate(false)`。
`sendBufferingUpdate` 会向 EventChannel 发缓冲事件，若此刻播放器已释放（见 P-1），异常发生在 `result` 已
回复之后，属于"无法回复"路径；调换顺序后先取值再发事件，异常可被 A 的 try/catch 兜住并正常回错。

**补丁**：

```kotlin
try {
    onMethodCall(call, result, textureId, player)
} catch (error: Throwable) {
    Log.e(TAG, "Platform call ${call.method} failed", error)
    result.error(
        "better_player_error",
        error.message ?: "BetterPlayer platform call failed",
        null
    )
}

POSITION_METHOD -> {
    val position = player.position
    player.sendBufferingUpdate(false)
    result.success(position)
}
```

### P-3 `lib/src/video_player/video_player.dart`：控制器生命周期与轮询定时器

四处实质改动（其余 hunk 均为 `dart format`）：

1. **`dispose()` 幂等且先置位**：上游先 `await _creatingCompleter.future` 再判断 `_isDisposed`；补丁改为
   先判断并置位 `_isDisposed = true`，再取消定时器、`await _creatingCompleter.future`、清空 `value`、
   取消事件订阅、释放平台资源、关闭事件流。避免"初始化尚未完成时 dispose"造成的重复释放，
   也让后续 `play()` / `position` 立刻看到已销毁状态。
2. **`position` / `absolutePosition` 守卫条件修正**：上游写的是 `if (!value.initialized && _isDisposed)`
   （与语义相反），补丁改为 `if (!value.initialized || _isDisposed)`。上游版本在"已销毁但 value 仍标记
   initialized"时会继续调用平台通道，触发 P-1 的崩溃路径。
3. **`_applyPlayPause` 的 300ms 轮询定时器**：进入前与回调内都加 `_isDisposed || !value.initialized` 检查，
   命中即 `timer.cancel()`；回调体包 `try { ... } on Object { timer.cancel(); }`，避免平台调用失败后
   定时器永久泄漏（上游只 `return`，定时器仍在跑）。
4. 若干 `dart format` 换行调整（`VideoPlayerValue.erroneous`、`enablePictureInPicture`、`build` 等），
   无行为差异。

## 升级上游时的操作步骤

1. 下载目标版本归档：
   `curl -sSLO https://pub.dev/api/archives/better_player_plus-<version>.tar.gz`
2. 解包到临时目录，与 `third_party/better_player_plus` 做 `diff -rq`，逐个确认差异是否属于上文 P-1 ~ P-3。
3. 上游若已合并某项补丁，从本文档删除对应条目；若上游改动了同一函数，需要重新移植而不是覆盖。
4. 升级后必须真机回归：进入/退出播放器各 20 次看 `adb logcat` 是否还有 `PlatformException` / `IllegalStateException`；
   播放中切后台再回前台；下载完成后立即进入播放器播放本地文件；HLS 直播源切换码率。
5. 同步更新本文件顶部的版本号与归档 SHA-256。

## 注意

- 本目录**不要**再跑 `dart format`（CI 的 format 门禁只查 `lib test tool`，不查 `third_party`）。
  已经重排过的文件保持原样即可，再格式化一次只会扩大与上游的 diff。
- 本目录**在** `flutter analyze` 与 CI `dart format` 的扫描范围内（根 `analysis_options.yaml` 未 exclude 它，
  实测 `dart analyze third_party/better_player_plus` → "No issues found!"）。因此 vendored 代码必须保持可分析；
  若上游新版本触发本仓库启用的 lint（目前只有 `directives_ordering`），优先在根 `analysis_options.yaml` 加 exclude，
  不要为了迎合本仓库风格去改 vendored 源码——那样下次升级 diff 会更难读。
