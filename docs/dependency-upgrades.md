# 依赖升级候选清单

> 本文是审查报告 P3-7 的落地物：把"有新版本"整理成**分批候选**，不是"可放心升"的许可。
> 数据采集时间：2026-10-25，采集命令 `flutter pub outdated --no-dev-dependencies`（Flutter 3.44.8 / Dart 3.12.2）。
> 升级前请重新跑一次该命令，版本号会随时间变化。

## 0. 基本判断规则

- **"Resolvable" 列**表示在当前 pubspec 约束内可以升到的最高版本；**"Latest"** 表示 pub.dev 上的最新版本。两者不同说明需要放宽约束。
- 同一批只动**一个主版本**依赖；每次升级后必须跑：
  ```bash
  flutter pub get
  dart run build_runner build --delete-conflicting-outputs
  dart format --output=none --set-exit-if-changed lib test tool
  flutter analyze --no-pub
  flutter test --no-pub
  dart run tool/generate_ui_localizations.dart --check
  ```
- 涉及原生插件（播放器、下载、存储、WebView、ML Kit）的升级，除了测试还要真机冒烟：登录 → 播放（含 HLS）→ 下载（含后台与恢复）→ WebView 挑战页 → 语言识别 → 数据库读写。
- **不要**把 `drift` 和 `drift_dev` 升到不同版本，也不要只改一个。

## 1. 第一批：同主版本内的小版本/补丁（风险最低）

| 包 | 当前 | 可升到 | 备注 |
| --- | --- | --- | --- |
| background_downloader | 9.5.7 | 9.5.9 | 只走补丁；跨到 9.6.x 见第 3 节 |
| connectivity_plus | 7.3.1 | 7.3.2 | |
| device_info_plus | 13.2.0 | 13.3.0 | |
| dio | 5.10.0 | 5.11.1 | 重试/取消语义改动会直接影响 `_get` 的重试逻辑 |
| dio_cookie_manager | 3.4.0 | 3.5.0 | 与 dio 一起升，保持 Cookie 拦截器一致 |
| flutter_cache_manager | 3.4.2 | 3.4.5 | 头像与封面缓存 |
| flutter_riverpod | 3.3.2 | 3.4.3 | 3.x 内小版本，注意 `ref.onDispose` 语义 |
| html | 0.15.6 | 0.15.7 | 解析器行为变化会影响 `site_parser` / `hanime1_parser` 的快照测试 |
| package_info_plus | 10.2.1 | 10.2.2 | |
| share_plus | 13.3.0 | 13.3.1 | |
| shared_preferences | 2.5.5 | 2.5.6 | |
| sqlite3 | 3.5.0 | 3.5.2 | 仍在 `^3.5.0` 约束内 |
| url_launcher | 6.3.2 | 6.3.3 | |
| video_player | 2.13.0 | 2.14.1 | 会连带抬高 `video_player_platform_interface` 的下限，与 pubspec.yaml 精确锁定的 6.9.0 冲突（见第 4 节），需同步更新测试替身 |
| wakelock_plus | 1.7.0 | 1.8.2 | 播放页常亮依赖它 |

## 2. 第二批：需要额外步骤或额外验证

| 包 | 当前 | 可升到 | 额外步骤 / 风险 |
| --- | --- | --- | --- |
| drift | 2.34.0（精确锁定） | 2.35.3 | 必须同时把 `drift_dev` 升到 2.35.x，重跑 build_runner；CI 会用 `git diff --exit-code lib/core/database/app_database.g.dart` 拦截生成物不一致。升完要跑 `test/drift` 全量迁移测试 |
| flutter_secure_storage | 10.3.1 | 10.3.4（10.x）/ 11.2.0（主版本） | 先只到 10.3.4；11.x 涉及 Android Keystore 迁移，已加密的 Cookie 与凭据可能读不出来，需要迁移或降级策略 |
| go_router | 17.3.0 | 17.5.0（17.x）/ 18.1.1（主版本） | 18.x 需核对 `errorBuilder` / `redirect` / `refreshListenable` 签名，以及 `lib/app/router/app_router.dart` 里 20+ 路由表 |
| google_mlkit_language_id | 0.14.0 | 0.15.1 | 0.x 版本，可能抬高 `minSdk`/`compileSdk`；升完要确认 `sourceLanguageDetector` 在设备上的模型下载行为 |
| cupertino_icons | 1.0.9 | 2.0.0 | 主版本，图标名有改名；只影响图标，但会编不过 |

## 3. 第三批：跨主版本，单独排期

| 包 | 当前 | 最新 | 风险点 |
| --- | --- | --- | --- |
| cached_network_image | 3.4.1 | 4.0.5 | 4.x 依赖 `cached_network_image_platform_interface ^5.0.0` 并新增 `material_ui` 依赖；`flutter_cache_manager` 仍在 3.4.5（目录兼容），但图片加载实现换了，需回归封面/头像占位与失败重试 |
| background_downloader | 9.5.7 | 9.6.4 | 9.6.x 改了任务恢复与数据库行为；与本仓库 P2-4（被杀任务重排）以及 `_finalizeCompletedTask` 的"先落库再删记录"顺序强相关，必须真机回归"杀进程后重进" |
| go_router | 17.3.0 | 18.1.1 | 见上 |

## 4. 不要动

| 包 | 原因 |
| --- | --- |
| intl | `flutter_localizations`（SDK）在 D:\Programs\flutter\packages\flutter_localizations\pubspec.yaml 里精确约束 `intl: 0.20.2`，`intl: any` 会被它钉住；升 intl 必须等 Flutter SDK 一起升 |
| native_dio_adapter 1.8.0 | 精确锁定，与 Cronet 引擎共享池（`lib/core/api/http_adapter_factory.dart`）绑定，升级需回归"共享适配器不重复创建/不互相 close" |
| drift / drift_dev | 见第 2 节，必须成对升级 |
| video_player_platform_interface 6.9.0 | dev 依赖精确锁定：widget 测试用它实现平台替身（见 docs/decisions/0012-fullscreen-player-lifecycle.md 的"验证"一节），版本必须与 video_player 匹配 |

## 5. 建议的执行顺序

1. 第一批一次性升完（同一 PR），跑全量测试；这一步不需要真机。
2. drift + drift_dev（单独 PR），确认生成物 diff 为空、`test/drift` 通过。
3. go_router 17.5.0（单独 PR）。
4. flutter_secure_storage 10.3.4（单独 PR，真机验证已登录状态仍在）。
5. google_mlkit_language_id、cupertino_icons。
6. 主版本（cached_network_image 4.x、flutter_secure_storage 11.x、go_router 18.x、background_downloader 9.6.x）各占一个 PR，逐个真机冒烟。
