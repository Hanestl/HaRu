# Issue #19 后续完善与回归记录

日期：2026-10-24（Asia/Shanghai）。基于交接报告 `D:\work\test\issue-19-status-report.md`，以及 `main` / `3036f72` 的未提交工作区继续完善。

## 本轮范围与实现

保留交接时的 17 个文件改动，未提交、未推送、未发布，也未修改 `pubspec.yaml` 的版本。

1. **Hanime 后台 GET 统一串行调度**：在 `Hanime1Api` 的后台入口统一排队，覆盖首页预热、频道刷新、相邻频道及视频详情预取。前一项结束后至少间隔 300ms 才启动下一项；前台请求直接执行。后台失败不阻塞队列，排队取消及时结束，API 关闭时终止在途及排队 Future。
2. **频道切换防抖**：标签立即选中，停留满 300ms 后才激活视频流并安排相邻频道预取；连续切换合并到最后一项。离开页面取消定时器。
3. **隐藏频道停止自动补页**：`VideoFeed` 隐藏后不再由滚动或首屏不足八条的补页循环继续加载后续页；已经发出的首屏请求可以正常回填。
4. **完整比较搜索筛选身份**：多选 `tags[]` / `brands[]` 使用全部查询值，兼容任意数字索引，按集合比较并忽略顺序、重复项；页码缺省为 1。签名改用结构化 JSON，避免搜索文本中的 `&sort=` 等内容与真正的参数产生碰撞。
5. 修正启动预热仍声称会弹前台验证的过期注释。

主要代码：

- `lib/core/api/hanime1_api.dart`
- `lib/core/api/hanime1_parser.dart`
- `lib/features/home/hanime_home_page.dart`
- `lib/shared/video_feed.dart`
- `lib/core/services/predictive_prefetch_service.dart`

不包含 Cookie 双向同步、代理、版本发布以及交接报告里尚未定位的其他异常。

## 自动化验证

| 检查 | 结果 |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test tool` | 228 个文件，0 改动 |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub --reporter expanded` | **592 通过，1 跳过** |
| Android `:app:lintDebug --no-daemon`，携带 `cronetHttpNoPlay=true` | BUILD SUCCESSFUL |
| `dart run tool/check_sensitive_files.dart` | 通过 |
| `git diff --check` | 通过 |
| Android arm64 Release 构建 | 成功 |

本轮增加 14 项测试：后台串行、间隔、前台绕过、失败续队、排队取消、在途取消、关闭清理；多选身份及分隔符碰撞；频道防抖、离页清理、已加载频道复用；隐藏频道不继续补页。

测试文件：`test/core/api/hanime1_api_test.dart`、`test/hanime1_parser_test.dart`、`test/features/home/hanime_home_page_test.dart`、`test/shared/video_feed_test.dart`。

## 真机验证与边界

设备：OnePlus 6T / Android 10 / API 29。最终安装包为同签名、非调试的 `com.hanestl.flule34`，`versionName=2.6.1`、`versionCode=2050`。

初次启动时手机断网，用户随后恢复网络；断网期间的空列表与网络错误不计入正常网络回归。

最终非调试包日志的已核对窗口为 **18:35:13.993502—18:39:53.776393**（UTC+08:00）：218 条记录、38 次 Hanime 请求成功、0 次 Hanime 拦截、0 条浏览器验证事件、0 条 ERROR。

| 交接场景 | 本轮真机结果与限制 |
| --- | --- |
| 冷启动及后台预热 | 正常网络下有内容、无验证弹窗；未触发 403，受限分支未验收 |
| 前台详情与验证成功后关闭 | 普通 Hanime 目标页及内嵌播放正常；本轮没有真实挑战，不能据此判定挑战通过后的关闭时序 |
| 验证卡片返回 / 关闭 | 未出现真实卡片，仍待受限网络回归；取消与冷却语义已有协调器单测 |
| 快速切换六个频道 | 两组连续点击覆盖最新上传、里番、泡面番、Motion Anime、3DCG、2.5D，内容正常，无弹窗；ADB 实际点击间隔约 330—433ms，超过防抖阈值，因此 300ms 内合并的结论来自 widget 测试，非这组真机点击 |
| R34V 播放列表 | 已实际进入并播放。上述日志窗口仅当前视频产生 1 次前台详情请求，没有 R34V 后台详情请求；尚未完整比对服务端全量历史的异步写入结果 |
| 无结果搜索 | 纯数字无匹配查询正常为空，退出重进再搜索仍为空；测试创建的两条搜索历史已逐条删除，未清空其他历史 |

账号登录状态、本地库及既有数据仍可正常读取；没有卸载或清除应用数据。播放回归本身会产生实际播放条目的正常观看记录。

原始日志未加入仓库，保留在本机临时目录 `haru-issue19-device/release-device-log.txt`；手机端本地导出文件为 `/storage/emulated/0/HaRu-logs-202610241840.txt`。未通过聊天、邮件或其他应用向外发送日志。

日志 SHA-256：`155015797dc31b08a8e4806f8ef254e6b993285aa7c122d57d69d8351d0713a0`。

**仍不能标记全部真机验收通过。** 必须补齐真实 403 下的挑战加载、自动关闭、取消后立即重试，以及同 host 请求失败后的防连闪。

2026-10-26 的 HaRu 2.6.2 发布未补齐上述受限场景；该版本依据 603 项自动化测试（1 跳过）、CI 质量门、签名/ABI 校验和本文件记录的真机基础回归发布。因此本记录仍不构成 #19 的关闭依据，后续需在真实 403 环境下补验。

## 安装版本码修正记录

首个构建错误地把已安装的 ABI 版本码 `2050` 当成 Flutter `--build-number`。Flutter arm64 分包又追加偏移，导致第一次实际安装为 `4050`。发现后已告知用户，并取得临时可调试过渡包的单独授权。

随后使用同签名的临时可调试包过渡，再保留数据安装正常 `2050` 包，最终核验 **2050、签名一致、无 DEBUGGABLE**。过渡配置仅存在于临时 Gradle init script，没有修改仓库的 Android 构建配置，也没有向仓库写入密钥或密码。

后续构建使用 `pubspec.yaml` 的原始 build number `50`，**不要把 ABI 偏移后的安装版本码再次传给 `--build-number`**。安装前先用 `aapt dump badging` 检查真实版本码、调试标记，用 `apksigner` 核对证书，再覆盖安装。

最终候选 APK：`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`。

SHA-256：`2052361245a2e6dacaf2be84140b019c37f48b86fca71efcec130ed821f89d2b`。

## 工具问题与后续建议

- 新建首页测试夹具最初重复释放 API，已修正；间隔测试在 FakeAsync 下挂起，改为真实计时，前台不等待后台另用受控在途请求验证。最终完整测试通过。
- 格式化换行曾使补丁匹配失败，已按当前文件内容重新应用。Windows 检索改用实际目录和 `rg -g`，避免不存在目录与路径通配符错误。
- context7 首次返回无关 Linux embedder 文档，已使用 Dart/Flutter 官方 API 定向核对。后续查询应拆分具体 API。
- ADB 字母输入被手机中文输入法转写，空态回归改用纯数字查询，并清理了测试记录。
- 构建工具仍提示部分插件使用旧 Kotlin Gradle Plugin、SDK XML 工具版本差异；签名工具有 Java 原生访问兼容提示。当前构建、签名、Lint 均成功，建议另开工具链升级任务，不在本轮混入依赖升级。
- 临时可调试包暴露了已有的 `Zone mismatch`（`lib/main.dart` 中绑定初始化与 `runApp` 的 zone 不同），以及 `scroll_to_top_overlay.dart:158` 对失活焦点 context 查祖先的断言。未修改这两处；最终非调试包上述日志窗口无 ERROR，不代表这两处根因消失，建议后续单独修复并补测。
- Cronet / WebView Cookie 属性同步仍按交接报告列为后续工作，未将 TLS、IP 或会话信誉假设当作已证实根因。
