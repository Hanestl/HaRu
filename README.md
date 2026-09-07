<p align="center">
  <img src="assets/branding/haru_icon.svg" width="128" alt="HaRu 图标">
</p>

<h1 align="center">HaRu</h1>

<p align="center">面向 Rule34Video 与 Hanime 的独立 Android 客户端</p>

<p align="center"><strong>简体中文</strong> · <a href="README_EN.md">English</a> · <a href="README_JA.md">日本語</a> · <a href="README_KO.md">한국어</a></p>

HaRu 使用两个网站现有的页面、接口与媒体源，在同一个应用中提供并列且相互独立的浏览、账号、媒体库和播放体验。

> [!IMPORTANT]
> 本项目与 Rule34Video、Hanime 官方均无关联。仅供已达到所在地法定成年年龄、且可合法访问相关内容的用户使用。

## 核心体验

- R34V 与 Hanime 是可独立进入、地位相同的一级内容来源，各自拥有首页、搜索、筛选和账号状态；
- 媒体库以“本机 / R34V / Hanime”为一级范围，统一整理历史、收藏或点赞、播放列表、订阅、稍后观看、本地库和下载；
- Hanime 支持登录与 Cloudflare 验证、分类浏览、完整筛选、点赞与踩、稍后观看、作者订阅、播放列表和评论互动；
- 视频详情支持多清晰度播放、下载、进度记忆、倍速、后台播放、循环播放，以及暂停时折叠播放器浏览简介和评论；
- 首页和列表提供缓存、相邻内容预取、失败恢复、单列或双列布局，并保留滚动与筛选状态；
- 提供与账号无关的本地分类库，以及可编辑、可导入导出的多语言内容翻译体系；
- 界面支持简体中文、English、日本語和한국어，底部导航与媒体库范围均可自由排序；
- 本地诊断日志自动脱敏、限制容量且仅保留最近 7 天，只有用户主动导出时才会离开设备。

## 安装

前往 [GitHub Releases](https://github.com/Hanestl/HaRu/releases/latest) 下载最新的 `arm64-v8a` APK，并可使用同一 Release 中的 `SHA256SUMS.txt` 校验完整性。

HaRu 支持 Android 7.0（API 24）及以上的 ARM64 手机和平板。侧载 APK 时，Android 可能要求允许浏览器或文件管理器“安装未知应用”。

## 数据与隐私

登录凭据保存在 Android 安全存储中；本地分类、下载记录、播放进度、设置、搜索历史和翻译数据保存在设备上。App 不集成广告、分析或第三方崩溃上报 SDK。

网站账号数据仍由对应网站管理。详细说明见 [PRIVACY.md](PRIVACY.md)。

## 本地构建

已验证环境：Flutter 3.44.8、Dart 3.12.2、JDK 25、Android SDK 36。

```powershell
flutter pub get
dart run build_runner build
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --split-per-abi --target-platform android-arm64 --no-pub
```

Release 签名与发布步骤见 [docs/release.md](docs/release.md)。

## 已知边界

- 功能依赖网站当前的 HTML、接口和登录流程；网站改版后可能需要同步更新解析器；
- App 不会绕过网站权限、付费限制、地区限制或 Cloudflare 验证；
- 视频地址可能带有时效参数，播放器和下载会在必要时重新获取来源。

## 开源协议

项目代码采用 [MIT License](LICENSE)。第三方组件继续遵循各自许可证，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 友情链接

- [LINUX DO](https://linux.do/)
