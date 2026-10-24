import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
  ];

  /// HaRu UI: 2.5D動畫
  ///
  /// In zh, this message translates to:
  /// **'2.5D動畫'**
  String get ui7b86fa60;

  /// HaRu UI: 20–60 分钟
  ///
  /// In zh, this message translates to:
  /// **'20–60 分钟'**
  String get ui0aedf15f;

  /// HaRu UI: 2D动画
  ///
  /// In zh, this message translates to:
  /// **'2D动画'**
  String get ui4a1b4e68;

  /// HaRu UI: 2D動畫
  ///
  /// In zh, this message translates to:
  /// **'2D動畫'**
  String get ui31e98877;

  /// HaRu UI: 5 分钟以内
  ///
  /// In zh, this message translates to:
  /// **'5 分钟以内'**
  String get ui4ebe1e15;

  /// HaRu UI: 5–20 分钟
  ///
  /// In zh, this message translates to:
  /// **'5–20 分钟'**
  String get ui594005ec;

  /// HaRu UI: 60 分钟以上
  ///
  /// In zh, this message translates to:
  /// **'60 分钟以上'**
  String get ui0be8a2c8;

  /// HaRu UI: ===== 最近 7 天日志 =====
  ///
  /// In zh, this message translates to:
  /// **'===== 最近 7 天日志 ====='**
  String get ui6e93de1b;

  /// HaRu UI: ===== 诊断信息 =====
  ///
  /// In zh, this message translates to:
  /// **'===== 诊断信息 ====='**
  String get ui2e77e7e1;

  /// HaRu UI: AI生成
  ///
  /// In zh, this message translates to:
  /// **'AI生成'**
  String get ui43396a35;

  /// HaRu UI: App 设置
  ///
  /// In zh, this message translates to:
  /// **'App 设置'**
  String get ui186386f2;

  /// HaRu UI: Chat 返回格式无效
  ///
  /// In zh, this message translates to:
  /// **'Chat 返回格式无效'**
  String get ui417bf31e;

  /// HaRu UI: DeepL 套餐与端点
  ///
  /// In zh, this message translates to:
  /// **'DeepL 套餐与端点'**
  String get ui14d5d228;

  /// HaRu UI: DeepL 返回格式无效
  ///
  /// In zh, this message translates to:
  /// **'DeepL 返回格式无效'**
  String get ui72f234b8;

  /// HaRu UI: Git 提交
  ///
  /// In zh, this message translates to:
  /// **'Git 提交'**
  String get ui57e4db6c;

  /// HaRu UI: GitHub 暂时拒绝了更新请求，请稍后重试或更换网络。
  ///
  /// In zh, this message translates to:
  /// **'GitHub 暂时拒绝了更新请求，请稍后重试或更换网络。'**
  String get ui4554eb7e;

  /// HaRu UI: GitHub 源代码
  ///
  /// In zh, this message translates to:
  /// **'GitHub 源代码'**
  String get ui1bcd541a;

  /// HaRu UI: HaRu 本地诊断日志
  ///
  /// In zh, this message translates to:
  /// **'HaRu 本地诊断日志'**
  String get ui20b6ac2f;

  /// HaRu UI: HaRu 翻译库
  ///
  /// In zh, this message translates to:
  /// **'HaRu 翻译库'**
  String get ui18362f38;

  /// HaRu UI: Hanime 历史删除
  ///
  /// In zh, this message translates to:
  /// **'Hanime 历史删除'**
  String get ui2a29886f;

  /// HaRu UI: Hanime 媒体库操作
  ///
  /// In zh, this message translates to:
  /// **'Hanime 媒体库操作'**
  String get ui48a1e8a9;

  /// HaRu UI: Hanime 官网登录
  ///
  /// In zh, this message translates to:
  /// **'Hanime 官网登录'**
  String get ui6a657fe9;

  /// HaRu UI: Hanime 播放列表
  ///
  /// In zh, this message translates to:
  /// **'Hanime 播放列表'**
  String get ui3fd23b15;

  /// HaRu UI: Hanime 暂不支持在应用内管理收藏。
  ///
  /// In zh, this message translates to:
  /// **'Hanime 暂不支持在应用内管理收藏。'**
  String get ui1e79d09d;

  /// HaRu UI: Hanime 点赞
  ///
  /// In zh, this message translates to:
  /// **'Hanime 点赞'**
  String get ui33a113c4;

  /// HaRu UI: Hanime 点赞操作
  ///
  /// In zh, this message translates to:
  /// **'Hanime 点赞操作'**
  String get ui2dff86e7;

  /// HaRu UI: Hanime 登录状态已失效，请在网页中重新登录后再试。
  ///
  /// In zh, this message translates to:
  /// **'Hanime 登录状态已失效，请在网页中重新登录后再试。'**
  String get ui5db4a68e;

  /// HaRu UI: Hanime 登录请求失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'Hanime 登录请求失败：{p0}'**
  String ui15642644(String p0);

  /// HaRu UI: Hanime 筛选与排序
  ///
  /// In zh, this message translates to:
  /// **'Hanime 筛选与排序'**
  String get ui0136f228;

  /// HaRu UI: Hanime 网络请求失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'Hanime 网络请求失败：{p0}'**
  String ui7dc6eb1b(String p0);

  /// HaRu UI: Hanime 评论操作
  ///
  /// In zh, this message translates to:
  /// **'Hanime 评论操作'**
  String get ui341110e9;

  /// HaRu UI: Hanime 详情页没有返回可播放的视频源。
  ///
  /// In zh, this message translates to:
  /// **'Hanime 详情页没有返回可播放的视频源。'**
  String get ui0fd18fa1;

  /// HaRu UI: Hanime 账号
  ///
  /// In zh, this message translates to:
  /// **'Hanime 账号'**
  String get ui27638fa8;

  /// HaRu UI: Hanime 账号头像上传
  ///
  /// In zh, this message translates to:
  /// **'Hanime 账号头像上传'**
  String get ui4ac3cece;

  /// HaRu UI: Hanime 页面受到 Cloudflare 限制，浏览器辅助访问未完成。
  ///
  /// In zh, this message translates to:
  /// **'Hanime 页面受到 Cloudflare 限制，浏览器辅助访问未完成。'**
  String get ui4b73143a;

  /// HaRu UI: Hanime 验证
  ///
  /// In zh, this message translates to:
  /// **'Hanime 验证'**
  String get ui77cbd28c;

  /// HaRu UI: Messages 返回格式无效
  ///
  /// In zh, this message translates to:
  /// **'Messages 返回格式无效'**
  String get ui2e244a94;

  /// HaRu UI: MyMemory 可用邮箱标识提高免费额度。
  ///
  /// In zh, this message translates to:
  /// **'MyMemory 可用邮箱标识提高免费额度。'**
  String get ui103930a8;

  /// HaRu UI: MyMemory 返回格式无效
  ///
  /// In zh, this message translates to:
  /// **'MyMemory 返回格式无效'**
  String get ui345ef1cb;

  /// HaRu UI: MyMemory 返回状态 {p0}
  ///
  /// In zh, this message translates to:
  /// **'MyMemory 返回状态 {p0}'**
  String ui76229bcf(String p0);

  /// HaRu UI: Responses 返回格式无效
  ///
  /// In zh, this message translates to:
  /// **'Responses 返回格式无效'**
  String get ui74b8531a;

  /// HaRu UI: Rule34Video 账号
  ///
  /// In zh, this message translates to:
  /// **'Rule34Video 账号'**
  String get ui2c98e3c6;

  /// HaRu UI: Wi-Fi 使用默认清晰度，移动网络最高 480p
  ///
  /// In zh, this message translates to:
  /// **'Wi-Fi 使用默认清晰度，移动网络最高 480p'**
  String get ui45943bf3;

  /// HaRu UI: Wi-Fi 最高 720p，移动网络最高 360p
  ///
  /// In zh, this message translates to:
  /// **'Wi-Fi 最高 720p，移动网络最高 360p'**
  String get ui34eda443;

  /// HaRu UI: {p0} - {p1} 秒
  ///
  /// In zh, this message translates to:
  /// **'{p0} - {p1} 秒'**
  String ui78defc63(String p0, String p1);

  /// HaRu UI: {p0} · 已下载
  ///
  /// In zh, this message translates to:
  /// **'{p0} · 已下载'**
  String ui3bebb943(String p0);

  /// HaRu UI: {p0} · 已失效
  ///
  /// In zh, this message translates to:
  /// **'{p0} · 已失效'**
  String ui152a8991(String p0);

  /// HaRu UI: {p0} · 正在校验
  ///
  /// In zh, this message translates to:
  /// **'{p0} · 正在校验'**
  String ui409b192f(String p0);

  /// HaRu UI: {p0} · 生效
  ///
  /// In zh, this message translates to:
  /// **'{p0} · 生效'**
  String ui1e263a03(String p0);

  /// HaRu UI: {p0} 个视频
  ///
  /// In zh, this message translates to:
  /// **'{p0} 个视频'**
  String ui167ae392(String p0);

  /// HaRu UI: {p0} 位订阅者
  ///
  /// In zh, this message translates to:
  /// **'{p0} 位订阅者'**
  String ui6aad5282(String p0);

  /// HaRu UI: {p0} 已加入下载队列。
  ///
  /// In zh, this message translates to:
  /// **'{p0} 已加入下载队列。'**
  String ui4e278fff(String p0);

  /// HaRu UI: {p0} 已在下载管理中。
  ///
  /// In zh, this message translates to:
  /// **'{p0} 已在下载管理中。'**
  String ui5e77ec72(String p0);

  /// HaRu UI: {p0} 年
  ///
  /// In zh, this message translates to:
  /// **'{p0} 年'**
  String ui4cc52a83(String p0);

  /// HaRu UI: {p0} 月
  ///
  /// In zh, this message translates to:
  /// **'{p0} 月'**
  String ui196d3c87(String p0);

  /// HaRu UI: {p0} 未配置模型名
  ///
  /// In zh, this message translates to:
  /// **'{p0} 未配置模型名'**
  String ui3f6d7631(String p0);

  /// HaRu UI: {p0} 次观看
  ///
  /// In zh, this message translates to:
  /// **'{p0} 次观看'**
  String ui67c16b0b(String p0);

  /// HaRu UI: {p0} 正在加入下载队列。
  ///
  /// In zh, this message translates to:
  /// **'{p0} 正在加入下载队列。'**
  String ui3455223c(String p0);

  /// HaRu UI: {p0} 票
  ///
  /// In zh, this message translates to:
  /// **'{p0} 票'**
  String ui7025b0dd(String p0);

  /// HaRu UI: {p0} 连接成功
  ///
  /// In zh, this message translates to:
  /// **'{p0} 连接成功'**
  String ui69ba5039(String p0);

  /// HaRu UI: {p0} 部影片
  ///
  /// In zh, this message translates to:
  /// **'{p0} 部影片'**
  String ui2f3746eb(String p0);

  /// HaRu UI: {p0}% · {p1} 票
  ///
  /// In zh, this message translates to:
  /// **'{p0}% · {p1} 票'**
  String ui44f14c54(String p0, String p1);

  /// HaRu UI: {p0}{p1}；译文：{p2}{p3}
  ///
  /// In zh, this message translates to:
  /// **'{p0}{p1}；译文：{p2}{p3}'**
  String ui278d8aed(String p0, String p1, String p2, String p3);

  /// HaRu UI: {p0}失败：{p1}
  ///
  /// In zh, this message translates to:
  /// **'{p0}失败：{p1}'**
  String ui5d9cbb2c(String p0, String p1);

  /// HaRu UI: {p0}（内置新增
  ///
  /// In zh, this message translates to:
  /// **'{p0}（内置新增'**
  String ui581b1dd5(String p0);

  /// HaRu UI: {p0}（内置新增 v{p1}）
  ///
  /// In zh, this message translates to:
  /// **'{p0}（内置新增 v{p1}）'**
  String ui5ab8d170(String p0, String p1);

  /// HaRu UI: {p0}（精选 {p1}）
  ///
  /// In zh, this message translates to:
  /// **'{p0}（精选 {p1}）'**
  String ui13d9e100(String p0, String p1);

  /// HaRu UI: “{p0}”及其列表关系将被删除，视频本身不受影响。
  ///
  /// In zh, this message translates to:
  /// **'“{p0}”及其列表关系将被删除，视频本身不受影响。'**
  String ui3e04ce6a(String p0);

  /// HaRu UI: 一列
  ///
  /// In zh, this message translates to:
  /// **'一列'**
  String get ui2046553b;

  /// HaRu UI: 一键更新
  ///
  /// In zh, this message translates to:
  /// **'一键更新'**
  String get ui0a9e6b7f;

  /// HaRu UI: 万
  ///
  /// In zh, this message translates to:
  /// **'万'**
  String get ui12469822;

  /// HaRu UI: 上一个
  ///
  /// In zh, this message translates to:
  /// **'上一个'**
  String get ui0b8ef7e3;

  /// HaRu UI: 上传者
  ///
  /// In zh, this message translates to:
  /// **'上传者'**
  String get ui5e2af7ea;

  /// HaRu UI: 上传者资料加载失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'上传者资料加载失败：{p0}'**
  String ui772dc31b(String p0);

  /// HaRu UI: 上传者：{p0}
  ///
  /// In zh, this message translates to:
  /// **'上传者：{p0}'**
  String ui29700171(String p0);

  /// HaRu UI: 下一个
  ///
  /// In zh, this message translates to:
  /// **'下一个'**
  String get ui58a06980;

  /// HaRu UI: 下载
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get ui175900a0;

  /// HaRu UI: 下载任务已被系统中断，请重试。
  ///
  /// In zh, this message translates to:
  /// **'下载任务已被系统中断，请重试。'**
  String get ui564d53e4;

  /// HaRu UI: 下载任务被系统中断，请重试。
  ///
  /// In zh, this message translates to:
  /// **'下载任务被系统中断，请重试。'**
  String get ui5cfc38c2;

  /// HaRu UI: 下载失败
  ///
  /// In zh, this message translates to:
  /// **'下载失败'**
  String get ui16f20943;

  /// HaRu UI: 下载属于本机功能，退出登录不会取消下载或删除公共目录中的文件。
  ///
  /// In zh, this message translates to:
  /// **'下载属于本机功能，退出登录不会取消下载或删除公共目录中的文件。'**
  String get ui07298d42;

  /// HaRu UI: 下载文件
  ///
  /// In zh, this message translates to:
  /// **'下载文件'**
  String get ui29e8ad9e;

  /// HaRu UI: 下载文件和记录已删除。
  ///
  /// In zh, this message translates to:
  /// **'下载文件和记录已删除。'**
  String get ui5ecf7c24;

  /// HaRu UI: 下载文件已失效或没有可播放此 MP4 的应用。
  ///
  /// In zh, this message translates to:
  /// **'下载文件已失效或没有可播放此 MP4 的应用。'**
  String get ui7fc5cfeb;

  /// HaRu UI: 下载更新包失败（HTTP {p0}），请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'下载更新包失败（HTTP {p0}），请稍后重试。'**
  String ui495af0fd(String p0);

  /// HaRu UI: 下载更新包失败，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'下载更新包失败，请稍后重试。'**
  String get ui714ebd00;

  /// HaRu UI: 下载更新包超时，请检查网络后重试。
  ///
  /// In zh, this message translates to:
  /// **'下载更新包超时，请检查网络后重试。'**
  String get ui225e3259;

  /// HaRu UI: 下载服务暂不可用。
  ///
  /// In zh, this message translates to:
  /// **'下载服务暂不可用。'**
  String get ui5cade6e1;

  /// HaRu UI: 下载清晰度
  ///
  /// In zh, this message translates to:
  /// **'下载清晰度'**
  String get ui180a6fbf;

  /// HaRu UI: 下载记录已删除。
  ///
  /// In zh, this message translates to:
  /// **'下载记录已删除。'**
  String get ui3187db03;

  /// HaRu UI: 下载设置
  ///
  /// In zh, this message translates to:
  /// **'下载设置'**
  String get ui49483396;

  /// HaRu UI: 不会删除下载的视频或账号数据。
  ///
  /// In zh, this message translates to:
  /// **'不会删除下载的视频或账号数据。'**
  String get ui350fa41c;

  /// HaRu UI: 不存在
  ///
  /// In zh, this message translates to:
  /// **'不存在'**
  String get ui10ebf8e5;

  /// HaRu UI: 不支持的翻译库版本：{p0}
  ///
  /// In zh, this message translates to:
  /// **'不支持的翻译库版本：{p0}'**
  String ui2d12eadf(String p0);

  /// HaRu UI: 不是 AI 翻译协议
  ///
  /// In zh, this message translates to:
  /// **'不是 AI 翻译协议'**
  String get ui22dbd975;

  /// HaRu UI: 不是 HaRu 翻译库文件
  ///
  /// In zh, this message translates to:
  /// **'不是 HaRu 翻译库文件'**
  String get ui2970e3de;

  /// HaRu UI: 不限
  ///
  /// In zh, this message translates to:
  /// **'不限'**
  String get ui34e49ede;

  /// HaRu UI: 不限时长
  ///
  /// In zh, this message translates to:
  /// **'不限时长'**
  String get ui6c2ca0b8;

  /// HaRu UI: 不限时间
  ///
  /// In zh, this message translates to:
  /// **'不限时间'**
  String get ui733128eb;

  /// HaRu UI: 两列
  ///
  /// In zh, this message translates to:
  /// **'两列'**
  String get ui7447788f;

  /// HaRu UI: 两次输入的新密码不一致。
  ///
  /// In zh, this message translates to:
  /// **'两次输入的新密码不一致。'**
  String get ui5fde6c76;

  /// HaRu UI: 个月
  ///
  /// In zh, this message translates to:
  /// **'个月'**
  String get ui7d332b29;

  /// HaRu UI: 主题
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get ui557a9537;

  /// HaRu UI: 主题模式
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get ui7b7ae9f2;

  /// HaRu UI: 举报
  ///
  /// In zh, this message translates to:
  /// **'举报'**
  String get ui754aed9c;

  /// HaRu UI: 举报失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'举报失败：{p0}'**
  String ui099fb842(String p0);

  /// HaRu UI: 举报已提交。
  ///
  /// In zh, this message translates to:
  /// **'举报已提交。'**
  String get ui0d483756;

  /// HaRu UI: 举报评论
  ///
  /// In zh, this message translates to:
  /// **'举报评论'**
  String get ui72607f99;

  /// HaRu UI: 亿
  ///
  /// In zh, this message translates to:
  /// **'亿'**
  String get ui2a3fe43c;

  /// HaRu UI: 仅 Wi-Fi 下载
  ///
  /// In zh, this message translates to:
  /// **'仅 Wi-Fi 下载'**
  String get ui11b84182;

  /// HaRu UI: 仅使用 Wi-Fi 下载
  ///
  /// In zh, this message translates to:
  /// **'仅使用 Wi-Fi 下载'**
  String get ui3d863311;

  /// HaRu UI: 仅保存在本机，自动脱敏，保留最近 7 天。
  /// {p0}
  ///
  /// In zh, this message translates to:
  /// **'仅保存在本机，自动脱敏，保留最近 7 天。\n{p0}'**
  String ui49859040(String p0);

  /// HaRu UI: 仅删除记录
  ///
  /// In zh, this message translates to:
  /// **'仅删除记录'**
  String get ui3bf7470b;

  /// HaRu UI: 仅在视频正在播放时生效，暂停或离开页面后自动恢复。
  ///
  /// In zh, this message translates to:
  /// **'仅在视频正在播放时生效，暂停或离开页面后自动恢复。'**
  String get ui730f65d7;

  /// HaRu UI: 仅显示已验证上传者
  ///
  /// In zh, this message translates to:
  /// **'仅显示已验证上传者'**
  String get ui709d26fa;

  /// HaRu UI: 仅登录后按账号保存；关闭后不再记录新搜索。
  ///
  /// In zh, this message translates to:
  /// **'仅登录后按账号保存；关闭后不再记录新搜索。'**
  String get ui51418311;

  /// HaRu UI: 今天
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get ui42cab9da;

  /// HaRu UI: 从头连续播放
  ///
  /// In zh, this message translates to:
  /// **'从头连续播放'**
  String get ui44ac200e;

  /// HaRu UI: 从播放列表移除
  ///
  /// In zh, this message translates to:
  /// **'从播放列表移除'**
  String get ui794510bf;

  /// HaRu UI: 他们在看
  ///
  /// In zh, this message translates to:
  /// **'他们在看'**
  String get ui4da21b44;

  /// HaRu UI: 他們在看
  ///
  /// In zh, this message translates to:
  /// **'他們在看'**
  String get ui1c2804ab;

  /// HaRu UI: 你可以只删除下载记录并保留视频，也可以同时删除公共目录中的视频。
  ///
  /// In zh, this message translates to:
  /// **'你可以只删除下载记录并保留视频，也可以同时删除公共目录中的视频。'**
  String get ui4a42f091;

  /// HaRu UI: 使用翻译服务
  ///
  /// In zh, this message translates to:
  /// **'使用翻译服务'**
  String get ui566537cc;

  /// HaRu UI: 例如：喜欢的动画、待整理
  ///
  /// In zh, this message translates to:
  /// **'例如：喜欢的动画、待整理'**
  String get ui65962099;

  /// HaRu UI: 保存
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get ui29629697;

  /// HaRu UI: 保存搜索历史
  ///
  /// In zh, this message translates to:
  /// **'保存搜索历史'**
  String get ui76444c7d;

  /// HaRu UI: 保存更新通道失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'保存更新通道失败：{p0}'**
  String ui4dc6233e(String p0);

  /// HaRu UI: 保存翻译失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'保存翻译失败：{p0}'**
  String ui69df41e4(String p0);

  /// HaRu UI: 保存翻译服务失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'保存翻译服务失败：{p0}'**
  String ui696410b7(String p0);

  /// HaRu UI: 保存设置失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'保存设置失败：{p0}'**
  String ui3e44bdb9(String p0);

  /// HaRu UI: 保持设备当前方向
  ///
  /// In zh, this message translates to:
  /// **'保持设备当前方向'**
  String get ui65d91d2b;

  /// HaRu UI: 保留已经下载到公共目录的视频
  ///
  /// In zh, this message translates to:
  /// **'保留已经下载到公共目录的视频'**
  String get ui4f586a83;

  /// HaRu UI: 修改
  ///
  /// In zh, this message translates to:
  /// **'修改'**
  String get ui06b0c857;

  /// HaRu UI: 修改失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'修改失败：{p0}'**
  String ui4ee78cab(String p0);

  /// HaRu UI: 修改密码
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get ui30350f33;

  /// HaRu UI: 修改显示名称与邮箱
  ///
  /// In zh, this message translates to:
  /// **'修改显示名称与邮箱'**
  String get ui3daf2795;

  /// HaRu UI: 修改邮箱
  ///
  /// In zh, this message translates to:
  /// **'修改邮箱'**
  String get ui043de786;

  /// HaRu UI: 個月
  ///
  /// In zh, this message translates to:
  /// **'個月'**
  String get ui1d0485f9;

  /// HaRu UI: 億
  ///
  /// In zh, this message translates to:
  /// **'億'**
  String get ui5545b6b8;

  /// HaRu UI: 全屏
  ///
  /// In zh, this message translates to:
  /// **'全屏'**
  String get ui4fcf2a14;

  /// HaRu UI: 全屏方向
  ///
  /// In zh, this message translates to:
  /// **'全屏方向'**
  String get ui784e54fd;

  /// HaRu UI: 全部
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get ui0e1cd927;

  /// HaRu UI: 全部清除
  ///
  /// In zh, this message translates to:
  /// **'全部清除'**
  String get ui2a504352;

  /// HaRu UI: 共 {p0} 个任务 · 已完成 {p1} 个 · 约占用 {p2}
  ///
  /// In zh, this message translates to:
  /// **'共 {p0} 个任务 · 已完成 {p1} 个 · 约占用 {p2}'**
  String ui78d96dee(String p0, String p1, String p2);

  /// HaRu UI: 共 {p0} 条 · 内置 {p1} · API {p2} · 用户 {p3}
  ///
  /// In zh, this message translates to:
  /// **'共 {p0} 条 · 内置 {p1} · API {p2} · 用户 {p3}'**
  String ui3b4a622d(String p0, String p1, String p2, String p3);

  /// HaRu UI: 共{p0}集
  ///
  /// In zh, this message translates to:
  /// **'共{p0}集'**
  String ui7aeb2e98(String p0);

  /// HaRu UI: 关于 HaRu
  ///
  /// In zh, this message translates to:
  /// **'关于 HaRu'**
  String get ui64efd37a;

  /// HaRu UI: 关闭
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get ui361cc8b7;

  /// HaRu UI: 关闭后将清除全部本地播放进度。
  ///
  /// In zh, this message translates to:
  /// **'关闭后将清除全部本地播放进度。'**
  String get ui29c40c72;

  /// HaRu UI: 关闭并清除
  ///
  /// In zh, this message translates to:
  /// **'关闭并清除'**
  String get ui02e95068;

  /// HaRu UI: 关闭记忆播放进度？
  ///
  /// In zh, this message translates to:
  /// **'关闭记忆播放进度？'**
  String get ui08354b81;

  /// HaRu UI: 其他举报理由
  ///
  /// In zh, this message translates to:
  /// **'其他举报理由'**
  String get ui19d54932;

  /// HaRu UI: 其他檢舉理由
  ///
  /// In zh, this message translates to:
  /// **'其他檢舉理由'**
  String get ui25e3dc9e;

  /// HaRu UI: 内容取向
  ///
  /// In zh, this message translates to:
  /// **'内容取向'**
  String get ui2bbc0423;

  /// HaRu UI: 内容设置
  ///
  /// In zh, this message translates to:
  /// **'内容设置'**
  String get ui4804490f;

  /// HaRu UI: 内置
  ///
  /// In zh, this message translates to:
  /// **'内置'**
  String get ui38d59e4d;

  /// HaRu UI: 写入更新包失败，请检查设备存储空间后重试。
  ///
  /// In zh, this message translates to:
  /// **'写入更新包失败，请检查设备存储空间后重试。'**
  String get ui3245a83c;

  /// HaRu UI: 出错了，请稍后重试
  ///
  /// In zh, this message translates to:
  /// **'出错了，请稍后重试'**
  String get ui0ff3423a;

  /// HaRu UI: 分享
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get ui2f5fd7d1;

  /// HaRu UI: 分类
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get ui55599ffb;

  /// HaRu UI: 分类：{p0}
  ///
  /// In zh, this message translates to:
  /// **'分类：{p0}'**
  String ui685042ae(String p0);

  /// HaRu UI: 分鐘
  ///
  /// In zh, this message translates to:
  /// **'分鐘'**
  String get ui748ee6f9;

  /// HaRu UI: 分钟
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get ui75929c3a;

  /// HaRu UI: 列表循环
  ///
  /// In zh, this message translates to:
  /// **'列表循环'**
  String get ui38fe9b1d;

  /// HaRu UI: 列表顺序
  ///
  /// In zh, this message translates to:
  /// **'列表顺序'**
  String get ui309e167e;

  /// HaRu UI: 创建
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get ui542b3ce5;

  /// HaRu UI: 创建自定义分类后，可以从任意视频的“本地分类库”按钮保存到这里。
  ///
  /// In zh, this message translates to:
  /// **'创建自定义分类后，可以从任意视频的“本地分类库”按钮保存到这里。'**
  String get ui0c2c660a;

  /// HaRu UI: 删除
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get ui1ae0ab8e;

  /// HaRu UI: 删除 API 译文
  ///
  /// In zh, this message translates to:
  /// **'删除 API 译文'**
  String get ui1cb9a6d7;

  /// HaRu UI: 删除“{p0}”？
  ///
  /// In zh, this message translates to:
  /// **'删除“{p0}”？'**
  String ui2d23933f(String p0);

  /// HaRu UI: 删除下载？
  ///
  /// In zh, this message translates to:
  /// **'删除下载？'**
  String get ui3913a7a5;

  /// HaRu UI: 删除全部下载记录
  ///
  /// In zh, this message translates to:
  /// **'删除全部下载记录'**
  String get ui6beb71f2;

  /// HaRu UI: 删除全部下载记录及对应视频
  ///
  /// In zh, this message translates to:
  /// **'删除全部下载记录及对应视频'**
  String get ui4e3e94a5;

  /// HaRu UI: 删除全部下载记录，并删除公共目录中仍能对应上的视频。无法删除文件的记录会保留。
  ///
  /// In zh, this message translates to:
  /// **'删除全部下载记录，并删除公共目录中仍能对应上的视频。无法删除文件的记录会保留。'**
  String get ui32521bda;

  /// HaRu UI: 删除全部失效下载记录
  ///
  /// In zh, this message translates to:
  /// **'删除全部失效下载记录'**
  String get ui499f4bf1;

  /// HaRu UI: 删除全部已经找不到严格对应文件的下载记录，不会触碰外部文件。
  ///
  /// In zh, this message translates to:
  /// **'删除全部已经找不到严格对应文件的下载记录，不会触碰外部文件。'**
  String get ui7622d7c4;

  /// HaRu UI: 删除历史记录
  ///
  /// In zh, this message translates to:
  /// **'删除历史记录'**
  String get ui7a6fcf0e;

  /// HaRu UI: 删除所选 API 译文？
  ///
  /// In zh, this message translates to:
  /// **'删除所选 API 译文？'**
  String get ui42079bac;

  /// HaRu UI: 删除播放列表？
  ///
  /// In zh, this message translates to:
  /// **'删除播放列表？'**
  String get ui16040b00;

  /// HaRu UI: 删除文件和记录
  ///
  /// In zh, this message translates to:
  /// **'删除文件和记录'**
  String get ui6882566e;

  /// HaRu UI: 删除翻译服务失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'删除翻译服务失败：{p0}'**
  String ui13dbc37c(String p0);

  /// HaRu UI: 删除翻译服务？
  ///
  /// In zh, this message translates to:
  /// **'删除翻译服务？'**
  String get ui377546a6;

  /// HaRu UI: 删除自定义翻译
  ///
  /// In zh, this message translates to:
  /// **'删除自定义翻译'**
  String get ui58aa0fc9;

  /// HaRu UI: 删除这台设备上的全部应用日志。
  ///
  /// In zh, this message translates to:
  /// **'删除这台设备上的全部应用日志。'**
  String get ui59ee6b29;

  /// HaRu UI: 刷新
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get ui057a59bf;

  /// HaRu UI: 刷新后仍未找到可播放的视频源。
  ///
  /// In zh, this message translates to:
  /// **'刷新后仍未找到可播放的视频源。'**
  String get ui1a88cf99;

  /// HaRu UI: 刷新后已找不到 {p0} 下载源。
  ///
  /// In zh, this message translates to:
  /// **'刷新后已找不到 {p0} 下载源。'**
  String ui30d8aa7b(String p0);

  /// HaRu UI: 刷新后已找不到 {p0} 下载源，请重新选择清晰度。
  ///
  /// In zh, this message translates to:
  /// **'刷新后已找不到 {p0} 下载源，请重新选择清晰度。'**
  String ui1adad0d8(String p0);

  /// HaRu UI: 刷新视频地址失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'刷新视频地址失败：{p0}'**
  String ui1b5c10c1(String p0);

  /// HaRu UI: 前台内容开始加载
  ///
  /// In zh, this message translates to:
  /// **'前台内容开始加载'**
  String get ui50138d2b;

  /// HaRu UI: 加载下一视频失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'加载下一视频失败：{p0}'**
  String ui7050fd74(String p0);

  /// HaRu UI: 加载视频失败。
  ///
  /// In zh, this message translates to:
  /// **'加载视频失败。'**
  String get ui11255e4d;

  /// HaRu UI: 勾选需要自动翻译的内容类型；仅在缺少本地译文且已配置可用翻译服务时请求。默认全部关闭。
  ///
  /// In zh, this message translates to:
  /// **'勾选需要自动翻译的内容类型；仅在缺少本地译文且已配置可用翻译服务时请求。默认全部关闭。'**
  String get ui2fbeba49;

  /// HaRu UI: 包名
  ///
  /// In zh, this message translates to:
  /// **'包名'**
  String get ui3caea101;

  /// HaRu UI: 匹配译名：{p0}
  ///
  /// In zh, this message translates to:
  /// **'匹配译名：{p0}'**
  String ui3c554cab(String p0);

  /// HaRu UI: 匿名用户
  ///
  /// In zh, this message translates to:
  /// **'匿名用户'**
  String get ui000f0cb3;

  /// HaRu UI: 单集循环
  ///
  /// In zh, this message translates to:
  /// **'单集循环'**
  String get ui71c021b7;

  /// HaRu UI: 历史
  ///
  /// In zh, this message translates to:
  /// **'历史'**
  String get ui1a330a72;

  /// HaRu UI: 历史累计最高评分艺术家
  ///
  /// In zh, this message translates to:
  /// **'历史累计最高评分艺术家'**
  String get ui51fa37c2;

  /// HaRu UI: 原文
  ///
  /// In zh, this message translates to:
  /// **'原文'**
  String get ui6ffe0a80;

  /// HaRu UI: 去设置
  ///
  /// In zh, this message translates to:
  /// **'去设置'**
  String get ui62f1bb01;

  /// HaRu UI: 双语
  ///
  /// In zh, this message translates to:
  /// **'双语'**
  String get ui54ec6c15;

  /// HaRu UI: 发一条评论...
  ///
  /// In zh, this message translates to:
  /// **'发一条评论...'**
  String get ui6c687b2d;

  /// HaRu UI: 发布日期
  ///
  /// In zh, this message translates to:
  /// **'发布日期'**
  String get ui2d79226f;

  /// HaRu UI: 发布时间
  ///
  /// In zh, this message translates to:
  /// **'发布时间'**
  String get ui2e2d0cb3;

  /// HaRu UI: 发现新版本
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get ui676a6b3b;

  /// HaRu UI: 发现新版本 {p0}。
  ///
  /// In zh, this message translates to:
  /// **'发现新版本 {p0}。'**
  String ui0e705d18(String p0);

  /// HaRu UI: 发表
  ///
  /// In zh, this message translates to:
  /// **'发表'**
  String get ui7d443475;

  /// HaRu UI: 发表失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'发表失败：{p0}'**
  String ui057b0ee1(String p0);

  /// HaRu UI: 发送
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get ui7a5d619c;

  /// HaRu UI: 取向：{p0}
  ///
  /// In zh, this message translates to:
  /// **'取向：{p0}'**
  String ui07cfc2d2(String p0);

  /// HaRu UI: 取消
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get ui1cdb9be3;

  /// HaRu UI: 取消回复
  ///
  /// In zh, this message translates to:
  /// **'取消回复'**
  String get ui4c580a79;

  /// HaRu UI: 取消收藏
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get ui0d684dfd;

  /// HaRu UI: 取消点赞
  ///
  /// In zh, this message translates to:
  /// **'取消点赞'**
  String get ui20eeb984;

  /// HaRu UI: 取消订阅
  ///
  /// In zh, this message translates to:
  /// **'取消订阅'**
  String get ui5eb70fab;

  /// HaRu UI: 取消选择
  ///
  /// In zh, this message translates to:
  /// **'取消选择'**
  String get ui78c52651;

  /// HaRu UI: 另有 {p0} 条内置译文，仅用于审计，
  ///
  /// In zh, this message translates to:
  /// **'另有 {p0} 条内置译文，仅用于审计，'**
  String ui072ad981(String p0);

  /// HaRu UI: 只会删除当前账号在这台设备上的搜索记录。此操作无法撤销。
  ///
  /// In zh, this message translates to:
  /// **'只会删除当前账号在这台设备上的搜索记录。此操作无法撤销。'**
  String get ui62d7fea9;

  /// HaRu UI: 只会清除当前账号在这台设备上的搜索记录。
  ///
  /// In zh, this message translates to:
  /// **'只会清除当前账号在这台设备上的搜索记录。'**
  String get ui35027352;

  /// HaRu UI: 只允许打开 HTTPS 链接。
  ///
  /// In zh, this message translates to:
  /// **'只允许打开 HTTPS 链接。'**
  String get ui51f9b5e4;

  /// HaRu UI: 只删除 App 中的全部下载记录，已经保存到 Download/Flule34 的视频会保留。进行中的任务会先取消。
  ///
  /// In zh, this message translates to:
  /// **'只删除 App 中的全部下载记录，已经保存到 Download/Flule34 的视频会保留。进行中的任务会先取消。'**
  String get ui73b35752;

  /// HaRu UI: 只删除本地分类记录，不会删除网站收藏、历史或已下载的视频。
  ///
  /// In zh, this message translates to:
  /// **'只删除本地分类记录，不会删除网站收藏、历史或已下载的视频。'**
  String get ui5a6e7dac;

  /// HaRu UI: 只移除已经找不到对应文件的记录
  ///
  /// In zh, this message translates to:
  /// **'只移除已经找不到对应文件的记录'**
  String get ui4f2368e4;

  /// HaRu UI: 可以只移除 App 内记录，也可以尝试删除当前记录所指向的外部文件。
  ///
  /// In zh, this message translates to:
  /// **'可以只移除 App 内记录，也可以尝试删除当前记录所指向的外部文件。'**
  String get ui713b1fb0;

  /// HaRu UI: 可跟随界面语言，也可单独指定；不同目标语言的译文会分别保存。
  ///
  /// In zh, this message translates to:
  /// **'可跟随界面语言，也可单独指定；不同目标语言的译文会分别保存。'**
  String get ui76ae23ba;

  /// HaRu UI: 同性
  ///
  /// In zh, this message translates to:
  /// **'同性'**
  String get ui19e0d4bf;

  /// HaRu UI: 同时下载任务数
  ///
  /// In zh, this message translates to:
  /// **'同时下载任务数'**
  String get ui2b2e17e5;

  /// HaRu UI: 同时删除公共目录中仍能对应上的视频
  ///
  /// In zh, this message translates to:
  /// **'同时删除公共目录中仍能对应上的视频'**
  String get ui09e67cd1;

  /// HaRu UI: 同步失败，已恢复原状态：{p0}
  ///
  /// In zh, this message translates to:
  /// **'同步失败，已恢复原状态：{p0}'**
  String ui30e251a0(String p0);

  /// HaRu UI: 同类条件和不同类型条件均取交集，每类最多选择 5 项。
  ///
  /// In zh, this message translates to:
  /// **'同类条件和不同类型条件均取交集，每类最多选择 5 项。'**
  String get ui3898538c;

  /// HaRu UI: 名称
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get ui73f2614f;

  /// HaRu UI: 后台任务进行中
  ///
  /// In zh, this message translates to:
  /// **'后台任务进行中'**
  String get ui3a38a6d4;

  /// HaRu UI: 后台播放
  ///
  /// In zh, this message translates to:
  /// **'后台播放'**
  String get ui7f54b07b;

  /// HaRu UI: 后台订阅整理已让位于当前操作。
  ///
  /// In zh, this message translates to:
  /// **'后台订阅整理已让位于当前操作。'**
  String get ui02a3d205;

  /// HaRu UI: 后台预加载已让位于当前操作。
  ///
  /// In zh, this message translates to:
  /// **'后台预加载已让位于当前操作。'**
  String get ui30c46183;

  /// HaRu UI: 否
  ///
  /// In zh, this message translates to:
  /// **'否'**
  String get ui4763b5c2;

  /// HaRu UI: 周
  ///
  /// In zh, this message translates to:
  /// **'周'**
  String get ui2f676191;

  /// HaRu UI: 命中任一排除条件的视频不会显示
  ///
  /// In zh, this message translates to:
  /// **'命中任一排除条件的视频不会显示'**
  String get ui63f37124;

  /// HaRu UI: 品牌
  ///
  /// In zh, this message translates to:
  /// **'品牌'**
  String get ui7ff6d3a0;

  /// HaRu UI: 回到顶部
  ///
  /// In zh, this message translates to:
  /// **'回到顶部'**
  String get ui3791c2b8;

  /// HaRu UI: 回复
  ///
  /// In zh, this message translates to:
  /// **'回复'**
  String get ui2c3700bb;

  /// HaRu UI: 回复 {p0}
  ///
  /// In zh, this message translates to:
  /// **'回复 {p0}'**
  String ui452cfc99(String p0);

  /// HaRu UI: 回复...
  ///
  /// In zh, this message translates to:
  /// **'回复...'**
  String get ui1b8fd367;

  /// HaRu UI: 回复内容不能为空。
  ///
  /// In zh, this message translates to:
  /// **'回复内容不能为空。'**
  String get ui0efec179;

  /// HaRu UI: 回复加载失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'回复加载失败：{p0}'**
  String ui24039614(String p0);

  /// HaRu UI: 回复已发表。
  ///
  /// In zh, this message translates to:
  /// **'回复已发表。'**
  String get ui54c6440e;

  /// HaRu UI: 图片
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get ui649f8b36;

  /// HaRu UI: 图片缓存已清除。
  ///
  /// In zh, this message translates to:
  /// **'图片缓存已清除。'**
  String get ui03a2a222;

  /// HaRu UI: 在本机保存，与登录账号无关
  ///
  /// In zh, this message translates to:
  /// **'在本机保存，与登录账号无关'**
  String get ui796e3b4c;

  /// HaRu UI: 在线观看历史暂时为空。
  ///
  /// In zh, this message translates to:
  /// **'在线观看历史暂时为空。'**
  String get ui164112a2;

  /// HaRu UI: 在网站中修改头像、名称和公开资料
  ///
  /// In zh, this message translates to:
  /// **'在网站中修改头像、名称和公开资料'**
  String get ui12562321;

  /// HaRu UI: 在网站中管理已上传的视频
  ///
  /// In zh, this message translates to:
  /// **'在网站中管理已上传的视频'**
  String get ui304779ae;

  /// HaRu UI: 基址
  ///
  /// In zh, this message translates to:
  /// **'基址'**
  String get ui1f55def5;

  /// HaRu UI: 基础条件
  ///
  /// In zh, this message translates to:
  /// **'基础条件'**
  String get ui6bdfd846;

  /// HaRu UI: 复制
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get ui461541d8;

  /// HaRu UI: 复制版本、设备和配置摘要，不包含 Cookie 或密码
  ///
  /// In zh, this message translates to:
  /// **'复制版本、设备和配置摘要，不包含 Cookie 或密码'**
  String get ui5dd6981a;

  /// HaRu UI: 复制翻译服务失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'复制翻译服务失败：{p0}'**
  String ui61570e3e(String p0);

  /// HaRu UI: 复制诊断信息
  ///
  /// In zh, this message translates to:
  /// **'复制诊断信息'**
  String get ui0ca5a4ba;

  /// HaRu UI: 外部文件大小已发生变化。
  ///
  /// In zh, this message translates to:
  /// **'外部文件大小已发生变化。'**
  String get ui2a4866c9;

  /// HaRu UI: 外部文件已不存在。
  ///
  /// In zh, this message translates to:
  /// **'外部文件已不存在。'**
  String get ui46887217;

  /// HaRu UI: 外部文件已被改名。
  ///
  /// In zh, this message translates to:
  /// **'外部文件已被改名。'**
  String get ui510839e9;

  /// HaRu UI: 外部文件当前无法读取。
  ///
  /// In zh, this message translates to:
  /// **'外部文件当前无法读取。'**
  String get ui3be928a0;

  /// HaRu UI: 天
  ///
  /// In zh, this message translates to:
  /// **'天'**
  String get ui31f6973f;

  /// HaRu UI: 头像已更新。
  ///
  /// In zh, this message translates to:
  /// **'头像已更新。'**
  String get ui281b9ca1;

  /// HaRu UI: 头像更新失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'头像更新失败：{p0}'**
  String ui5ea25aa8(String p0);

  /// HaRu UI: 始终使用默认清晰度
  ///
  /// In zh, this message translates to:
  /// **'始终使用默认清晰度'**
  String get ui158640ea;

  /// HaRu UI: 媒体库
  ///
  /// In zh, this message translates to:
  /// **'媒体库'**
  String get ui17588e00;

  /// HaRu UI: 媒体库范围顺序
  ///
  /// In zh, this message translates to:
  /// **'媒体库范围顺序'**
  String get ui2a120a57;

  /// HaRu UI: 存在
  ///
  /// In zh, this message translates to:
  /// **'存在'**
  String get ui344971fc;

  /// HaRu UI: 安全合并
  ///
  /// In zh, this message translates to:
  /// **'安全合并'**
  String get ui60514b78;

  /// HaRu UI: 安全证书验证失败
  ///
  /// In zh, this message translates to:
  /// **'安全证书验证失败'**
  String get ui0a4deada;

  /// HaRu UI: 安装包签名与已安装版本不一致，无法覆盖安装，请前往 GitHub 手动下载安装。
  ///
  /// In zh, this message translates to:
  /// **'安装包签名与已安装版本不一致，无法覆盖安装，请前往 GitHub 手动下载安装。'**
  String get ui67804bce;

  /// HaRu UI: 安装更新包失败，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'安装更新包失败，请稍后重试。'**
  String get ui4573775f;

  /// HaRu UI: 安装超时，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'安装超时，请稍后重试。'**
  String get ui4768e1cf;

  /// HaRu UI: 宽泛搜索
  ///
  /// In zh, this message translates to:
  /// **'宽泛搜索'**
  String get ui2cfae1da;

  /// HaRu UI: 密码
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get ui5baf4155;

  /// HaRu UI: 密码已更新。
  ///
  /// In zh, this message translates to:
  /// **'密码已更新。'**
  String get ui0a68072d;

  /// HaRu UI: 导入失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{p0}'**
  String ui65cceef6(String p0);

  /// HaRu UI: 导入或导出
  ///
  /// In zh, this message translates to:
  /// **'导入或导出'**
  String get ui4181e94a;

  /// HaRu UI: 导入文件优先
  ///
  /// In zh, this message translates to:
  /// **'导入文件优先'**
  String get ui347e69e0;

  /// HaRu UI: 导入时会忽略。请选择冲突处理方式。
  ///
  /// In zh, this message translates to:
  /// **'导入时会忽略。请选择冲突处理方式。'**
  String get ui7b8b8627;

  /// HaRu UI: 导入翻译库
  ///
  /// In zh, this message translates to:
  /// **'导入翻译库'**
  String get ui3447243f;

  /// HaRu UI: 导出日志
  ///
  /// In zh, this message translates to:
  /// **'导出日志'**
  String get ui29108110;

  /// HaRu UI: 导出日志失败，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'导出日志失败，请稍后重试。'**
  String get ui561390c3;

  /// HaRu UI: 导出时间：{p0}
  ///
  /// In zh, this message translates to:
  /// **'导出时间：{p0}'**
  String ui4bddfd15(String p0);

  /// HaRu UI: 导出翻译库
  ///
  /// In zh, this message translates to:
  /// **'导出翻译库'**
  String get ui1a3a31c6;

  /// HaRu UI: 导出翻译库失败。
  ///
  /// In zh, this message translates to:
  /// **'导出翻译库失败。'**
  String get ui2d28ccb0;

  /// HaRu UI: 将删除“{p0}”及其本机密钥。
  ///
  /// In zh, this message translates to:
  /// **'将删除“{p0}”及其本机密钥。'**
  String ui0d4b5d1d(String p0);

  /// HaRu UI: 将删除本机保存的 Hanime 账号、密码和登录会话。
  ///
  /// In zh, this message translates to:
  /// **'将删除本机保存的 Hanime 账号、密码和登录会话。'**
  String get ui410820fb;

  /// HaRu UI: 将删除本机保存的账号、密码和登录会话；设备下载与本地分类库不会受影响。
  ///
  /// In zh, this message translates to:
  /// **'将删除本机保存的账号、密码和登录会话；设备下载与本地分类库不会受影响。'**
  String get ui5116cc17;

  /// HaRu UI: 将删除这台设备上的全部诊断日志，此操作无法撤销。
  ///
  /// In zh, this message translates to:
  /// **'将删除这台设备上的全部诊断日志，此操作无法撤销。'**
  String get ui206e15fd;

  /// HaRu UI: 将永久删除 {p0} 条 API 译文。用户手动译文和内置译文不会被删除。
  ///
  /// In zh, this message translates to:
  /// **'将永久删除 {p0} 条 API 译文。用户手动译文和内置译文不会被删除。'**
  String ui61998fc7(String p0);

  /// HaRu UI: 小时
  ///
  /// In zh, this message translates to:
  /// **'小时'**
  String get ui1ba660cc;

  /// HaRu UI: 小時
  ///
  /// In zh, this message translates to:
  /// **'小時'**
  String get ui17aba12e;

  /// HaRu UI: 尚未开启安装权限，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'尚未开启安装权限，请稍后重试。'**
  String get ui422fcf83;

  /// HaRu UI: 尚未登录
  ///
  /// In zh, this message translates to:
  /// **'尚未登录'**
  String get ui2d851aa0;

  /// HaRu UI: 尚未选择{p0}
  ///
  /// In zh, this message translates to:
  /// **'尚未选择{p0}'**
  String ui5a665aac(String p0);

  /// HaRu UI: 尚未配置翻译服务。内置词表和用户手动译文仍可正常使用。
  ///
  /// In zh, this message translates to:
  /// **'尚未配置翻译服务。内置词表和用户手动译文仍可正常使用。'**
  String get ui7d437796;

  /// HaRu UI: 展开
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get ui59bc6fa1;

  /// HaRu UI: 展开({p0})
  ///
  /// In zh, this message translates to:
  /// **'展开({p0})'**
  String ui605cc69a(String p0);

  /// HaRu UI: 已下载
  ///
  /// In zh, this message translates to:
  /// **'已下载'**
  String get ui0543d520;

  /// HaRu UI: 已下载 {p0}
  ///
  /// In zh, this message translates to:
  /// **'已下载 {p0}'**
  String ui21b8fcdc(String p0);

  /// HaRu UI: 已下载 {p0} / {p1}
  ///
  /// In zh, this message translates to:
  /// **'已下载 {p0} / {p1}'**
  String ui419fd1e2(String p0, String p1);

  /// HaRu UI: 已从“{p0}”移出。
  ///
  /// In zh, this message translates to:
  /// **'已从“{p0}”移出。'**
  String ui4c1b3a95(String p0);

  /// HaRu UI: 已从播放列表“{p0}”移出。
  ///
  /// In zh, this message translates to:
  /// **'已从播放列表“{p0}”移出。'**
  String ui228152d7(String p0);

  /// HaRu UI: 已从播放列表移出。
  ///
  /// In zh, this message translates to:
  /// **'已从播放列表移出。'**
  String get ui1fa11a46;

  /// HaRu UI: 已从本地库移出。
  ///
  /// In zh, this message translates to:
  /// **'已从本地库移出。'**
  String get ui64769355;

  /// HaRu UI: 已关闭
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get ui55781737;

  /// HaRu UI: 已删除 {p0} 条下载记录。
  ///
  /// In zh, this message translates to:
  /// **'已删除 {p0} 条下载记录。'**
  String ui69dc1173(String p0);

  /// HaRu UI: 已删除 {p0} 条，{p1} 条未能删除。
  ///
  /// In zh, this message translates to:
  /// **'已删除 {p0} 条，{p1} 条未能删除。'**
  String ui5ed2011c(String p0, String p1);

  /// HaRu UI: 已加入“{p0}”。
  ///
  /// In zh, this message translates to:
  /// **'已加入“{p0}”。'**
  String ui5846e503(String p0);

  /// HaRu UI: 已加入播放列表“{p0}”。
  ///
  /// In zh, this message translates to:
  /// **'已加入播放列表“{p0}”。'**
  String ui6b12697d(String p0);

  /// HaRu UI: 已加入收藏。
  ///
  /// In zh, this message translates to:
  /// **'已加入收藏。'**
  String get ui670889d8;

  /// HaRu UI: 已加入稍后观看。
  ///
  /// In zh, this message translates to:
  /// **'已加入稍后观看。'**
  String get ui0b279e7e;

  /// HaRu UI: 已取消
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get ui37453e63;

  /// HaRu UI: 已取消下载更新包。
  ///
  /// In zh, this message translates to:
  /// **'已取消下载更新包。'**
  String get ui2374725a;

  /// HaRu UI: 已取消安装。
  ///
  /// In zh, this message translates to:
  /// **'已取消安装。'**
  String get ui0c5e75d4;

  /// HaRu UI: 已取消收藏。
  ///
  /// In zh, this message translates to:
  /// **'已取消收藏。'**
  String get ui7bbd0e24;

  /// HaRu UI: 已取消点赞。
  ///
  /// In zh, this message translates to:
  /// **'已取消点赞。'**
  String get ui5cbef487;

  /// HaRu UI: 已取消订阅。
  ///
  /// In zh, this message translates to:
  /// **'已取消订阅。'**
  String get ui34a0e3be;

  /// HaRu UI: 已取消订阅艺术家。
  ///
  /// In zh, this message translates to:
  /// **'已取消订阅艺术家。'**
  String get ui67f81f43;

  /// HaRu UI: 已学习标题 · {p0}
  ///
  /// In zh, this message translates to:
  /// **'已学习标题 · {p0}'**
  String ui1db0bde1(String p0);

  /// HaRu UI: 已导入 {p0} 层译文
  ///
  /// In zh, this message translates to:
  /// **'已导入 {p0} 层译文'**
  String ui7a8ce229(String p0);

  /// HaRu UI: 已开启
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get ui0de2ecda;

  /// HaRu UI: 已收藏
  ///
  /// In zh, this message translates to:
  /// **'已收藏'**
  String get ui0077d937;

  /// HaRu UI: 已新建并加入播放列表“{p0}”。
  ///
  /// In zh, this message translates to:
  /// **'已新建并加入播放列表“{p0}”。'**
  String ui2ce07361(String p0);

  /// HaRu UI: 已暂停
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get ui1a7827b1;

  /// HaRu UI: 已点赞。
  ///
  /// In zh, this message translates to:
  /// **'已点赞。'**
  String get ui24c8bd29;

  /// HaRu UI: 已移出稍后观看。
  ///
  /// In zh, this message translates to:
  /// **'已移出稍后观看。'**
  String get ui76ec3129;

  /// HaRu UI: 已稍后观看
  ///
  /// In zh, this message translates to:
  /// **'已稍后观看'**
  String get ui7acf6891;

  /// HaRu UI: 已经到底了
  ///
  /// In zh, this message translates to:
  /// **'已经到底了'**
  String get ui49531ef1;

  /// HaRu UI: 已经存在同名的本地库。
  ///
  /// In zh, this message translates to:
  /// **'已经存在同名的本地库。'**
  String get ui15a96bf1;

  /// HaRu UI: 已经是播放列表最后一个视频。
  ///
  /// In zh, this message translates to:
  /// **'已经是播放列表最后一个视频。'**
  String get ui69288ef8;

  /// HaRu UI: 已订阅
  ///
  /// In zh, this message translates to:
  /// **'已订阅'**
  String get ui24d4c17d;

  /// HaRu UI: 已订阅。
  ///
  /// In zh, this message translates to:
  /// **'已订阅。'**
  String get ui426dc524;

  /// HaRu UI: 已订阅上传者。
  ///
  /// In zh, this message translates to:
  /// **'已订阅上传者。'**
  String get ui59a2ec21;

  /// HaRu UI: 已订阅艺术家。
  ///
  /// In zh, this message translates to:
  /// **'已订阅艺术家。'**
  String get ui7bf7bdc9;

  /// HaRu UI: 已选 {p0} 个
  ///
  /// In zh, this message translates to:
  /// **'已选 {p0} 个'**
  String ui1d63803b(String p0);

  /// HaRu UI: 已选择 {p0} 项
  ///
  /// In zh, this message translates to:
  /// **'已选择 {p0} 项'**
  String ui21a8fcc4(String p0);

  /// HaRu UI: 已重新加入下载队列。
  ///
  /// In zh, this message translates to:
  /// **'已重新加入下载队列。'**
  String get ui538facf2;

  /// HaRu UI: 已验证上传者
  ///
  /// In zh, this message translates to:
  /// **'已验证上传者'**
  String get ui1d982807;

  /// HaRu UI: 帮助与反馈
  ///
  /// In zh, this message translates to:
  /// **'帮助与反馈'**
  String get ui563d1236;

  /// HaRu UI: 平台
  ///
  /// In zh, this message translates to:
  /// **'平台'**
  String get ui62a81a58;

  /// HaRu UI: 年
  ///
  /// In zh, this message translates to:
  /// **'年'**
  String get ui4b2a99fd;

  /// HaRu UI: 年份
  ///
  /// In zh, this message translates to:
  /// **'年份'**
  String get ui25461fa7;

  /// HaRu UI: 广告内容或垃圾内容
  ///
  /// In zh, this message translates to:
  /// **'广告内容或垃圾内容'**
  String get ui1fb0206d;

  /// HaRu UI: 库名称
  ///
  /// In zh, this message translates to:
  /// **'库名称'**
  String get ui70131201;

  /// HaRu UI: 库名称不能为空。
  ///
  /// In zh, this message translates to:
  /// **'库名称不能为空。'**
  String get ui14bf4ac7;

  /// HaRu UI: 应用
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get ui643b8cff;

  /// HaRu UI: 应用 {p0} 个条件
  ///
  /// In zh, this message translates to:
  /// **'应用 {p0} 个条件'**
  String ui7be16f02(String p0);

  /// HaRu UI: 应用日志
  ///
  /// In zh, this message translates to:
  /// **'应用日志'**
  String get ui75af3770;

  /// HaRu UI: 应用日志已清除。
  ///
  /// In zh, this message translates to:
  /// **'应用日志已清除。'**
  String get ui38f27f7a;

  /// HaRu UI: 应用（不限）
  ///
  /// In zh, this message translates to:
  /// **'应用（不限）'**
  String get ui390d6cf3;

  /// HaRu UI: 底座网络适配器已释放，无法发起请求。
  ///
  /// In zh, this message translates to:
  /// **'底座网络适配器已释放，无法发起请求。'**
  String get ui256813a5;

  /// HaRu UI: 底部导航顺序
  ///
  /// In zh, this message translates to:
  /// **'底部导航顺序'**
  String get ui37fc4085;

  /// HaRu UI: 廣告內容或垃圾內容
  ///
  /// In zh, this message translates to:
  /// **'廣告內容或垃圾內容'**
  String get ui68701249;

  /// HaRu UI: 开启后，切换应用或关闭屏幕时继续播放声音。
  ///
  /// In zh, this message translates to:
  /// **'开启后，切换应用或关闭屏幕时继续播放声音。'**
  String get ui0a663237;

  /// HaRu UI: 开始日期
  ///
  /// In zh, this message translates to:
  /// **'开始日期'**
  String get ui12e4a250;

  /// HaRu UI: 开源许可
  ///
  /// In zh, this message translates to:
  /// **'开源许可'**
  String get ui13034753;

  /// HaRu UI: 异性
  ///
  /// In zh, this message translates to:
  /// **'异性'**
  String get ui1fbbcc39;

  /// HaRu UI: 当前任务会先被取消。你可以只删除记录，也可以同时清理未完成文件。
  ///
  /// In zh, this message translates to:
  /// **'当前任务会先被取消。你可以只删除记录，也可以同时清理未完成文件。'**
  String get ui573acdd9;

  /// HaRu UI: 当前密码
  ///
  /// In zh, this message translates to:
  /// **'当前密码'**
  String get ui2073fb01;

  /// HaRu UI: 当前已加载内容没有匹配项。
  ///
  /// In zh, this message translates to:
  /// **'当前已加载内容没有匹配项。'**
  String get ui3c131161;

  /// HaRu UI: 当前已是最新版本。
  ///
  /// In zh, this message translates to:
  /// **'当前已是最新版本。'**
  String get ui73c532ff;

  /// HaRu UI: 当前开发构建未配置更新源
  ///
  /// In zh, this message translates to:
  /// **'当前开发构建未配置更新源'**
  String get ui34a6f44b;

  /// HaRu UI: 当前开发构建未配置更新源。
  ///
  /// In zh, this message translates to:
  /// **'当前开发构建未配置更新源。'**
  String get ui2c29265e;

  /// HaRu UI: 当前未登录
  ///
  /// In zh, this message translates to:
  /// **'当前未登录'**
  String get ui309047a5;

  /// HaRu UI: 当前构建未配置仓库地址
  ///
  /// In zh, this message translates to:
  /// **'当前构建未配置仓库地址'**
  String get ui5cc85dd9;

  /// HaRu UI: 当前版本：{p0}
  ///
  /// In zh, this message translates to:
  /// **'当前版本：{p0}'**
  String ui34dcc5aa(String p0);

  /// HaRu UI: 当前环境没有可写入的翻译数据库
  ///
  /// In zh, this message translates to:
  /// **'当前环境没有可写入的翻译数据库'**
  String get ui09b4d081;

  /// HaRu UI: 当前设备不支持自动安装，请前往 GitHub 手动下载安装包。
  ///
  /// In zh, this message translates to:
  /// **'当前设备不支持自动安装，请前往 GitHub 手动下载安装包。'**
  String get ui111ba46f;

  /// HaRu UI: 当前账号 ID
  ///
  /// In zh, this message translates to:
  /// **'当前账号 ID'**
  String get ui1ef7e413;

  /// HaRu UI: 循环播放
  ///
  /// In zh, this message translates to:
  /// **'循环播放'**
  String get ui4f25fec3;

  /// HaRu UI: 必须同时包含
  ///
  /// In zh, this message translates to:
  /// **'必须同时包含'**
  String get ui761f6d4f;

  /// HaRu UI: 忘记密码
  ///
  /// In zh, this message translates to:
  /// **'忘记密码'**
  String get ui5362cf1f;

  /// HaRu UI: 忽略内置 {p0}。
  ///
  /// In zh, this message translates to:
  /// **'忽略内置 {p0}。'**
  String ui13e52148(String p0);

  /// HaRu UI: 恢复内置翻译
  ///
  /// In zh, this message translates to:
  /// **'恢复内置翻译'**
  String get ui1f9121af;

  /// HaRu UI: 恢复已学习翻译
  ///
  /// In zh, this message translates to:
  /// **'恢复已学习翻译'**
  String get ui608e380c;

  /// HaRu UI: 我的
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get ui67d3b06d;

  /// HaRu UI: 我的上传
  ///
  /// In zh, this message translates to:
  /// **'我的上传'**
  String get ui1065acd3;

  /// HaRu UI: 所有网络都使用上方选择的清晰度
  ///
  /// In zh, this message translates to:
  /// **'所有网络都使用上方选择的清晰度'**
  String get ui3ae6be59;

  /// HaRu UI: 所选本地库已经不存在。
  ///
  /// In zh, this message translates to:
  /// **'所选本地库已经不存在。'**
  String get ui2274fd3b;

  /// HaRu UI: 打开 GitHub 发布页
  ///
  /// In zh, this message translates to:
  /// **'打开 GitHub 发布页'**
  String get ui6fa5a093;

  /// HaRu UI: 打开{p0}集合
  ///
  /// In zh, this message translates to:
  /// **'打开{p0}集合'**
  String ui6ae92059(String p0);

  /// HaRu UI: 打开下载失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'打开下载失败：{p0}'**
  String ui580f715d(String p0);

  /// HaRu UI: 打开官方网站
  ///
  /// In zh, this message translates to:
  /// **'打开官方网站'**
  String get ui02a64714;

  /// HaRu UI: 打开网站反馈表单
  ///
  /// In zh, this message translates to:
  /// **'打开网站反馈表单'**
  String get ui0d472be2;

  /// HaRu UI: 打开网站消息中心
  ///
  /// In zh, this message translates to:
  /// **'打开网站消息中心'**
  String get ui0fb6d05e;

  /// HaRu UI: 打开艺术家视频
  ///
  /// In zh, this message translates to:
  /// **'打开艺术家视频'**
  String get ui2d1cd088;

  /// HaRu UI: 扶她
  ///
  /// In zh, this message translates to:
  /// **'扶她'**
  String get ui5c30a6ab;

  /// HaRu UI: 批量删除
  ///
  /// In zh, this message translates to:
  /// **'批量删除'**
  String get ui52437893;

  /// HaRu UI: 投票数 ≥ {p0}
  ///
  /// In zh, this message translates to:
  /// **'投票数 ≥ {p0}'**
  String ui41bd594d(String p0);

  /// HaRu UI: 报告不包含 Cookie、密码、邮箱、用户 ID 值或 Android 设备标识符。发送前仍建议自行检查。
  ///
  /// In zh, this message translates to:
  /// **'报告不包含 Cookie、密码、邮箱、用户 ID 值或 Android 设备标识符。发送前仍建议自行检查。'**
  String get ui7069486d;

  /// HaRu UI: 拉取模型列表
  ///
  /// In zh, this message translates to:
  /// **'拉取模型列表'**
  String get ui7d6a579d;

  /// HaRu UI: 指定月份…
  ///
  /// In zh, this message translates to:
  /// **'指定月份…'**
  String get ui4c4f7a5b;

  /// HaRu UI: 按原文排序
  ///
  /// In zh, this message translates to:
  /// **'按原文排序'**
  String get ui65af3a45;

  /// HaRu UI: 按名字
  ///
  /// In zh, this message translates to:
  /// **'按名字'**
  String get ui55e84e41;

  /// HaRu UI: 按最近更新排序
  ///
  /// In zh, this message translates to:
  /// **'按最近更新排序'**
  String get ui384e319d;

  /// HaRu UI: 按来源排序
  ///
  /// In zh, this message translates to:
  /// **'按来源排序'**
  String get ui7ab117f8;

  /// HaRu UI: 按观看量浏览热门内容
  ///
  /// In zh, this message translates to:
  /// **'按观看量浏览热门内容'**
  String get ui0db93df0;

  /// HaRu UI: 按译文排序
  ///
  /// In zh, this message translates to:
  /// **'按译文排序'**
  String get ui05f1a141;

  /// HaRu UI: 排序
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get ui4f8317d3;

  /// HaRu UI: 排序：{p0}
  ///
  /// In zh, this message translates to:
  /// **'排序：{p0}'**
  String ui702bc146(String p0);

  /// HaRu UI: 排行榜
  ///
  /// In zh, this message translates to:
  /// **'排行榜'**
  String get ui6b955ece;

  /// HaRu UI: 排除
  ///
  /// In zh, this message translates to:
  /// **'排除'**
  String get ui077c6159;

  /// HaRu UI: 排除内容
  ///
  /// In zh, this message translates to:
  /// **'排除内容'**
  String get ui20d42365;

  /// HaRu UI: 排除：
  ///
  /// In zh, this message translates to:
  /// **'排除：'**
  String get ui549d6c00;

  /// HaRu UI: 接口类型
  ///
  /// In zh, this message translates to:
  /// **'接口类型'**
  String get ui6ec4c172;

  /// HaRu UI: 接口类型或服务器已改变，请重新填写密钥
  ///
  /// In zh, this message translates to:
  /// **'接口类型或服务器已改变，请重新填写密钥'**
  String get ui7daaecfb;

  /// HaRu UI: 描述（可选）
  ///
  /// In zh, this message translates to:
  /// **'描述（可选）'**
  String get ui4aa4bf66;

  /// HaRu UI: 提交
  ///
  /// In zh, this message translates to:
  /// **'提交'**
  String get ui1d31a7a0;

  /// HaRu UI: 提交后台下载任务失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'提交后台下载任务失败：{p0}'**
  String ui0c0bc8f8(String p0);

  /// HaRu UI: 提示：长按标题、分类或标签，可以手动添加或修改译文。
  ///
  /// In zh, this message translates to:
  /// **'提示：长按标题、分类或标签，可以手动添加或修改译文。'**
  String get ui48d043db;

  /// HaRu UI: 搜索
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get ui7365d58c;

  /// HaRu UI: 搜索{p0}
  ///
  /// In zh, this message translates to:
  /// **'搜索{p0}'**
  String ui0726d620(String p0);

  /// HaRu UI: 搜索全部{p0}
  ///
  /// In zh, this message translates to:
  /// **'搜索全部{p0}'**
  String ui35022cd6(String p0);

  /// HaRu UI: 搜索历史
  ///
  /// In zh, this message translates to:
  /// **'搜索历史'**
  String get ui72dba787;

  /// HaRu UI: 搜索历史已清除。
  ///
  /// In zh, this message translates to:
  /// **'搜索历史已清除。'**
  String get ui60e69fcd;

  /// HaRu UI: 搜索历史清空失败，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'搜索历史清空失败，请稍后重试。'**
  String get ui7dd406e9;

  /// HaRu UI: 搜索原文、译文或翻译服务
  ///
  /// In zh, this message translates to:
  /// **'搜索原文、译文或翻译服务'**
  String get ui358b0b68;

  /// HaRu UI: 搜索在线观看历史
  ///
  /// In zh, this message translates to:
  /// **'搜索在线观看历史'**
  String get ui7e4e2643;

  /// HaRu UI: 搜索已加载的视频
  ///
  /// In zh, this message translates to:
  /// **'搜索已加载的视频'**
  String get ui6e169d07;

  /// HaRu UI: 搜索成功，但历史记录保存失败。
  ///
  /// In zh, this message translates to:
  /// **'搜索成功，但历史记录保存失败。'**
  String get ui66473d1e;

  /// HaRu UI: 搜索播放列表
  ///
  /// In zh, this message translates to:
  /// **'搜索播放列表'**
  String get ui7f749006;

  /// HaRu UI: 搜索播放列表中的视频
  ///
  /// In zh, this message translates to:
  /// **'搜索播放列表中的视频'**
  String get ui6d63717d;

  /// HaRu UI: 搜索收藏的视频
  ///
  /// In zh, this message translates to:
  /// **'搜索收藏的视频'**
  String get ui105d8758;

  /// HaRu UI: 搜索本地库
  ///
  /// In zh, this message translates to:
  /// **'搜索本地库'**
  String get ui7d976e17;

  /// HaRu UI: 搜索此库中的视频
  ///
  /// In zh, this message translates to:
  /// **'搜索此库中的视频'**
  String get ui342ff046;

  /// HaRu UI: 搜索此订阅中的视频
  ///
  /// In zh, this message translates to:
  /// **'搜索此订阅中的视频'**
  String get ui6cb88a74;

  /// HaRu UI: 搜索点赞的视频
  ///
  /// In zh, this message translates to:
  /// **'搜索点赞的视频'**
  String get ui6a8599b3;

  /// HaRu UI: 搜索稍后观看
  ///
  /// In zh, this message translates to:
  /// **'搜索稍后观看'**
  String get ui43f9c5a0;

  /// HaRu UI: 搜索观看历史
  ///
  /// In zh, this message translates to:
  /// **'搜索观看历史'**
  String get ui35231688;

  /// HaRu UI: 搜索视频、标签、分类或艺术家
  ///
  /// In zh, this message translates to:
  /// **'搜索视频、标签、分类或艺术家'**
  String get ui0e1e2e67;

  /// HaRu UI: 搜索订阅
  ///
  /// In zh, this message translates to:
  /// **'搜索订阅'**
  String get ui49f810e0;

  /// HaRu UI: 搜索记录删除失败，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'搜索记录删除失败，请稍后重试。'**
  String get ui761a4e53;

  /// HaRu UI: 撤销自定义
  ///
  /// In zh, this message translates to:
  /// **'撤销自定义'**
  String get ui645e5e1c;

  /// HaRu UI: 播放
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get ui73d23748;

  /// HaRu UI: 播放列表
  ///
  /// In zh, this message translates to:
  /// **'播放列表'**
  String get ui16f3ad93;

  /// HaRu UI: 播放列表 {p0}
  ///
  /// In zh, this message translates to:
  /// **'播放列表 {p0}'**
  String ui2189de41(String p0);

  /// HaRu UI: 播放列表会从网站账号中删除。
  ///
  /// In zh, this message translates to:
  /// **'播放列表会从网站账号中删除。'**
  String get ui264bb7d8;

  /// HaRu UI: 播放列表分页未取得进展，请刷新重试。
  ///
  /// In zh, this message translates to:
  /// **'播放列表分页未取得进展，请刷新重试。'**
  String get ui25177a33;

  /// HaRu UI: 播放列表加载失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'播放列表加载失败：{p0}'**
  String ui766b41bc(String p0);

  /// HaRu UI: 播放列表已创建。
  ///
  /// In zh, this message translates to:
  /// **'播放列表已创建。'**
  String get ui1f1bcb06;

  /// HaRu UI: 播放列表已创建并加入当前视频。
  ///
  /// In zh, this message translates to:
  /// **'播放列表已创建并加入当前视频。'**
  String get ui74ffe4ad;

  /// HaRu UI: 播放列表已创建，但未能读取新列表。
  ///
  /// In zh, this message translates to:
  /// **'播放列表已创建，但未能读取新列表。'**
  String get ui32c513bd;

  /// HaRu UI: 播放列表已删除。
  ///
  /// In zh, this message translates to:
  /// **'播放列表已删除。'**
  String get ui080bbabb;

  /// HaRu UI: 播放列表已更新。
  ///
  /// In zh, this message translates to:
  /// **'播放列表已更新。'**
  String get ui49fa8b9b;

  /// HaRu UI: 播放列表播放参数无效。
  ///
  /// In zh, this message translates to:
  /// **'播放列表播放参数无效。'**
  String get ui5ba71ce6;

  /// HaRu UI: 播放列表操作
  ///
  /// In zh, this message translates to:
  /// **'播放列表操作'**
  String get ui201d2aa4;

  /// HaRu UI: 播放列表操作失败。
  ///
  /// In zh, this message translates to:
  /// **'播放列表操作失败。'**
  String get ui59fbd342;

  /// HaRu UI: 播放列表编辑页面缺少标题字段。
  ///
  /// In zh, this message translates to:
  /// **'播放列表编辑页面缺少标题字段。'**
  String get ui6ef9f29e;

  /// HaRu UI: 播放器初始化后未提供视频时长。
  ///
  /// In zh, this message translates to:
  /// **'播放器初始化后未提供视频时长。'**
  String get ui7e8be483;

  /// HaRu UI: 播放文件
  ///
  /// In zh, this message translates to:
  /// **'播放文件'**
  String get ui206c2436;

  /// HaRu UI: 播放时保持屏幕常亮
  ///
  /// In zh, this message translates to:
  /// **'播放时保持屏幕常亮'**
  String get ui46f59caf;

  /// HaRu UI: 播放清晰度
  ///
  /// In zh, this message translates to:
  /// **'播放清晰度'**
  String get ui1c97d427;

  /// HaRu UI: 播放源失效时 App 会重新请求视频详情。仍无法播放时，请复制诊断信息并在反馈中说明视频链接和清晰度。
  ///
  /// In zh, this message translates to:
  /// **'播放源失效时 App 会重新请求视频详情。仍无法播放时，请复制诊断信息并在反馈中说明视频链接和清晰度。'**
  String get ui3940d7b7;

  /// HaRu UI: 播放设置
  ///
  /// In zh, this message translates to:
  /// **'播放设置'**
  String get ui03f9adce;

  /// HaRu UI: 播放速度
  ///
  /// In zh, this message translates to:
  /// **'播放速度'**
  String get ui5caccc11;

  /// HaRu UI: 播放问题
  ///
  /// In zh, this message translates to:
  /// **'播放问题'**
  String get ui21658def;

  /// HaRu UI: 操作失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'操作失败：{p0}'**
  String ui1c251464(String p0);

  /// HaRu UI: 操作未能完成，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'操作未能完成，请稍后重试。'**
  String get ui31d7af87;

  /// HaRu UI: 操作超时，请稍后重试
  ///
  /// In zh, this message translates to:
  /// **'操作超时，请稍后重试'**
  String get ui28c15475;

  /// HaRu UI: 支持 Google 一键登入或官网邮箱密码登录，登录完成后会自动返回。
  ///
  /// In zh, this message translates to:
  /// **'支持 Google 一键登入或官网邮箱密码登录，登录完成后会自动返回。'**
  String get ui5e1b9757;

  /// HaRu UI: 收藏
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get ui0d933ab7;

  /// HaRu UI: 收藏夹里还没有视频。
  ///
  /// In zh, this message translates to:
  /// **'收藏夹里还没有视频。'**
  String get ui60768862;

  /// HaRu UI: 收藏状态读取失败，点击重试
  ///
  /// In zh, this message translates to:
  /// **'收藏状态读取失败，点击重试'**
  String get ui00b01c4f;

  /// HaRu UI: 收起
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get ui453d0751;

  /// HaRu UI: 收起回复
  ///
  /// In zh, this message translates to:
  /// **'收起回复'**
  String get ui0b53ee0f;

  /// HaRu UI: 放宽匹配规则，可能返回标题仅部分匹配的结果。
  ///
  /// In zh, this message translates to:
  /// **'放宽匹配规则，可能返回标题仅部分匹配的结果。'**
  String get ui7d902f31;

  /// HaRu UI: 数据库结构
  ///
  /// In zh, this message translates to:
  /// **'数据库结构'**
  String get ui053602da;

  /// HaRu UI: 数据解析失败，站点结构可能已更新
  ///
  /// In zh, this message translates to:
  /// **'数据解析失败，站点结构可能已更新'**
  String get ui146d33d9;

  /// HaRu UI: 文件不存在
  ///
  /// In zh, this message translates to:
  /// **'文件不存在'**
  String get ui1ce03cf7;

  /// HaRu UI: 文件包含 API 译文 {p0} 条、
  ///
  /// In zh, this message translates to:
  /// **'文件包含 API 译文 {p0} 条、'**
  String ui37efec5c(String p0);

  /// HaRu UI: 新密码
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get ui27d4d033;

  /// HaRu UI: 新密码至少需要 8 个字符。
  ///
  /// In zh, this message translates to:
  /// **'新密码至少需要 8 个字符。'**
  String get ui59623fdc;

  /// HaRu UI: 新建
  ///
  /// In zh, this message translates to:
  /// **'新建'**
  String get ui17e77337;

  /// HaRu UI: 新建任务会等待符合条件的网络；已存在任务不被追溯修改。
  ///
  /// In zh, this message translates to:
  /// **'新建任务会等待符合条件的网络；已存在任务不被追溯修改。'**
  String get ui1b46740e;

  /// HaRu UI: 新建播放列表
  ///
  /// In zh, this message translates to:
  /// **'新建播放列表'**
  String get ui1062b8a1;

  /// HaRu UI: 新建本地库
  ///
  /// In zh, this message translates to:
  /// **'新建本地库'**
  String get ui264c8716;

  /// HaRu UI: 新建翻译服务
  ///
  /// In zh, this message translates to:
  /// **'新建翻译服务'**
  String get ui742da263;

  /// HaRu UI: 新版本 {p0} 已发布，是否立即下载并安装？
  ///
  /// In zh, this message translates to:
  /// **'新版本 {p0} 已发布，是否立即下载并安装？'**
  String ui0d7ee0fa(String p0);

  /// HaRu UI: 无
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get ui7bd4dd1e;

  /// HaRu UI: 无法启动系统安装器，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'无法启动系统安装器，请稍后重试。'**
  String get ui196ad4c7;

  /// HaRu UI: 无法启动系统安装器：{p0}
  ///
  /// In zh, this message translates to:
  /// **'无法启动系统安装器：{p0}'**
  String ui6f78c40a(String p0);

  /// HaRu UI: 无法将视频保存到 Download/Flule34。
  ///
  /// In zh, this message translates to:
  /// **'无法将视频保存到 Download/Flule34。'**
  String get ui3180d36c;

  /// HaRu UI: 无法打开分享面板：{p0}
  ///
  /// In zh, this message translates to:
  /// **'无法打开分享面板：{p0}'**
  String ui180bd386(String p0);

  /// HaRu UI: 无法打开链接：{p0}
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接：{p0}'**
  String ui07590f5f(String p0);

  /// HaRu UI: 无法播放此视频源：{p0}
  ///
  /// In zh, this message translates to:
  /// **'无法播放此视频源：{p0}'**
  String ui3a33698e(String p0);

  /// HaRu UI: 无法生成诊断信息：{p0}
  ///
  /// In zh, this message translates to:
  /// **'无法生成诊断信息：{p0}'**
  String ui310db05f(String p0);

  /// HaRu UI: 无法确定思考参数兼容方式
  ///
  /// In zh, this message translates to:
  /// **'无法确定思考参数兼容方式'**
  String get ui44f277c1;

  /// HaRu UI: 无法获取操作令牌。
  ///
  /// In zh, this message translates to:
  /// **'无法获取操作令牌。'**
  String get ui50aa2314;

  /// HaRu UI: 无法获取登录表单的校验令牌。
  ///
  /// In zh, this message translates to:
  /// **'无法获取登录表单的校验令牌。'**
  String get ui79cdaeac;

  /// HaRu UI: 无法解析上传者资料，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'无法解析上传者资料，请稍后重试。'**
  String get ui06546e23;

  /// HaRu UI: 无法解析当前账号资料，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'无法解析当前账号资料，请稍后重试。'**
  String get ui57f26ed1;

  /// HaRu UI: 无法解析账号编辑资料。
  ///
  /// In zh, this message translates to:
  /// **'无法解析账号编辑资料。'**
  String get ui33dbf598;

  /// HaRu UI: 无法识别视频作者。
  ///
  /// In zh, this message translates to:
  /// **'无法识别视频作者。'**
  String get ui15bf560f;

  /// HaRu UI: 无法识别这个上传者的订阅信息。
  ///
  /// In zh, this message translates to:
  /// **'无法识别这个上传者的订阅信息。'**
  String get ui5825923c;

  /// HaRu UI: 无法识别这个订阅，请从相关视频详情页{p0}。
  ///
  /// In zh, this message translates to:
  /// **'无法识别这个订阅，请从相关视频详情页{p0}。'**
  String ui6f7f557a(String p0);

  /// HaRu UI: 无法读取网页内容，可以点重试。
  ///
  /// In zh, this message translates to:
  /// **'无法读取网页内容，可以点重试。'**
  String get ui2dfcd562;

  /// HaRu UI: 无法连接 GitHub，请检查网络后重试。
  ///
  /// In zh, this message translates to:
  /// **'无法连接 GitHub，请检查网络后重试。'**
  String get ui0b6ddbbb;

  /// HaRu UI: 无法连接到网站
  ///
  /// In zh, this message translates to:
  /// **'无法连接到网站'**
  String get ui5262de17;

  /// HaRu UI: 无法连接到网站，请检查网络。
  ///
  /// In zh, this message translates to:
  /// **'无法连接到网站，请检查网络。'**
  String get ui67fe026b;

  /// HaRu UI: 日期：{p0}
  ///
  /// In zh, this message translates to:
  /// **'日期：{p0}'**
  String ui6991b83f(String p0);

  /// HaRu UI: 日本 IP 可能无法通过验证
  ///
  /// In zh, this message translates to:
  /// **'日本 IP 可能无法通过验证'**
  String get ui22636da6;

  /// HaRu UI: 日本語
  ///
  /// In zh, this message translates to:
  /// **'日本語'**
  String get ui005f5ce7;

  /// HaRu UI: 旧版自定义端点
  ///
  /// In zh, this message translates to:
  /// **'旧版自定义端点'**
  String get ui60361df0;

  /// HaRu UI: 时长
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get ui3754e1ab;

  /// HaRu UI: 时长最长
  ///
  /// In zh, this message translates to:
  /// **'时长最长'**
  String get ui194644ca;

  /// HaRu UI: 时长：{p0}
  ///
  /// In zh, this message translates to:
  /// **'时长：{p0}'**
  String ui7b627dbe(String p0);

  /// HaRu UI: 昨天
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get ui3ba0d1c3;

  /// HaRu UI: 是
  ///
  /// In zh, this message translates to:
  /// **'是'**
  String get ui16b646f4;

  /// HaRu UI: 显示名称
  ///
  /// In zh, this message translates to:
  /// **'显示名称'**
  String get ui5a80d5b4;

  /// HaRu UI: 显示密码
  ///
  /// In zh, this message translates to:
  /// **'显示密码'**
  String get ui6a379702;

  /// HaRu UI: 显示设置
  ///
  /// In zh, this message translates to:
  /// **'显示设置'**
  String get ui5e0f4440;

  /// HaRu UI: 暂停
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get ui7b1cd931;

  /// HaRu UI: 暂无诊断信息。
  ///
  /// In zh, this message translates to:
  /// **'暂无诊断信息。'**
  String get ui7167f83b;

  /// HaRu UI: 暂时无法检查更新，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'暂时无法检查更新，请稍后重试。'**
  String get ui585c23ff;

  /// HaRu UI: 暂时无法预览
  ///
  /// In zh, this message translates to:
  /// **'暂时无法预览'**
  String get ui47bde52d;

  /// HaRu UI: 暂时没有可展示的热门标签。
  ///
  /// In zh, this message translates to:
  /// **'暂时没有可展示的热门标签。'**
  String get ui2effb403;

  /// HaRu UI: 暴力或令人反感的內容
  ///
  /// In zh, this message translates to:
  /// **'暴力或令人反感的內容'**
  String get ui64683360;

  /// HaRu UI: 暴力或令人反感的内容
  ///
  /// In zh, this message translates to:
  /// **'暴力或令人反感的内容'**
  String get ui6b06a5db;

  /// HaRu UI: 更多
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get ui1902e077;

  /// HaRu UI: 更多操作
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get ui38e45090;

  /// HaRu UI: 更换头像
  ///
  /// In zh, this message translates to:
  /// **'更换头像'**
  String get ui2d102f6b;

  /// HaRu UI: 更新包下载失败，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'更新包下载失败，请稍后重试。'**
  String get ui0b0c36f2;

  /// HaRu UI: 更新包与当前系统不兼容。
  ///
  /// In zh, this message translates to:
  /// **'更新包与当前系统不兼容。'**
  String get ui1a5d4948;

  /// HaRu UI: 更新包保存不完整，请重试。
  ///
  /// In zh, this message translates to:
  /// **'更新包保存不完整，请重试。'**
  String get ui59cb7d12;

  /// HaRu UI: 更新包大小校验失败，请重试。
  ///
  /// In zh, this message translates to:
  /// **'更新包大小校验失败，请重试。'**
  String get ui4ebfc1da;

  /// HaRu UI: 更新包已安装完成。
  ///
  /// In zh, this message translates to:
  /// **'更新包已安装完成。'**
  String get ui75071796;

  /// HaRu UI: 更新包无效或已损坏，请重新下载。
  ///
  /// In zh, this message translates to:
  /// **'更新包无效或已损坏，请重新下载。'**
  String get ui7999a1cf;

  /// HaRu UI: 更新包校验失败，请重试。
  ///
  /// In zh, this message translates to:
  /// **'更新包校验失败，请重试。'**
  String get ui154411ba;

  /// HaRu UI: 更新失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'更新失败：{p0}'**
  String ui2bef8164(String p0);

  /// HaRu UI: 更新检查已完成。
  ///
  /// In zh, this message translates to:
  /// **'更新检查已完成。'**
  String get ui2ec2c481;

  /// HaRu UI: 更新源
  ///
  /// In zh, this message translates to:
  /// **'更新源'**
  String get ui17e1bbfa;

  /// HaRu UI: 更新源没有可用的 Android Release。
  ///
  /// In zh, this message translates to:
  /// **'更新源没有可用的 Android Release。'**
  String get ui0beabc18;

  /// HaRu UI: 更新源：{p0}
  ///
  /// In zh, this message translates to:
  /// **'更新源：{p0}'**
  String ui55d54121(String p0);

  /// HaRu UI: 更新说明
  ///
  /// In zh, this message translates to:
  /// **'更新说明'**
  String get ui19f3097b;

  /// HaRu UI: 更新通道
  ///
  /// In zh, this message translates to:
  /// **'更新通道'**
  String get ui1d030a86;

  /// HaRu UI: 更早的关注内容仍在整理，请重试加载。
  ///
  /// In zh, this message translates to:
  /// **'更早的关注内容仍在整理，请重试加载。'**
  String get ui7e47c566;

  /// HaRu UI: 最低投票数
  ///
  /// In zh, this message translates to:
  /// **'最低投票数'**
  String get ui69112ae8;

  /// HaRu UI: 最低点赞率
  ///
  /// In zh, this message translates to:
  /// **'最低点赞率'**
  String get ui65f28853;

  /// HaRu UI: 最低票数
  ///
  /// In zh, this message translates to:
  /// **'最低票数'**
  String get ui51a023ab;

  /// HaRu UI: 最多观看
  ///
  /// In zh, this message translates to:
  /// **'最多观看'**
  String get ui2b705f61;

  /// HaRu UI: 最新
  ///
  /// In zh, this message translates to:
  /// **'最新'**
  String get ui347c998f;

  /// HaRu UI: 最新上传
  ///
  /// In zh, this message translates to:
  /// **'最新上传'**
  String get ui6c3fd091;

  /// HaRu UI: 最新上傳
  ///
  /// In zh, this message translates to:
  /// **'最新上傳'**
  String get ui7a46e769;

  /// HaRu UI: 最新上市
  ///
  /// In zh, this message translates to:
  /// **'最新上市'**
  String get ui21368744;

  /// HaRu UI: 最新创建
  ///
  /// In zh, this message translates to:
  /// **'最新创建'**
  String get ui222ba90b;

  /// HaRu UI: 最新订阅
  ///
  /// In zh, this message translates to:
  /// **'最新订阅'**
  String get ui368db057;

  /// HaRu UI: 最早
  ///
  /// In zh, this message translates to:
  /// **'最早'**
  String get ui4778e5e1;

  /// HaRu UI: 最热
  ///
  /// In zh, this message translates to:
  /// **'最热'**
  String get ui4124f57e;

  /// HaRu UI: 最短时长（秒）
  ///
  /// In zh, this message translates to:
  /// **'最短时长（秒）'**
  String get ui7437a4c3;

  /// HaRu UI: 最近修改
  ///
  /// In zh, this message translates to:
  /// **'最近修改'**
  String get ui23dfffd1;

  /// HaRu UI: 最近更新
  ///
  /// In zh, this message translates to:
  /// **'最近更新'**
  String get ui6da2840c;

  /// HaRu UI: 最近添加
  ///
  /// In zh, this message translates to:
  /// **'最近添加'**
  String get ui5891390e;

  /// HaRu UI: 最近观看
  ///
  /// In zh, this message translates to:
  /// **'最近观看'**
  String get ui73804ab0;

  /// HaRu UI: 最长
  ///
  /// In zh, this message translates to:
  /// **'最长'**
  String get ui3f66748c;

  /// HaRu UI: 最长时长不能小于最短时长
  ///
  /// In zh, this message translates to:
  /// **'最长时长不能小于最短时长'**
  String get ui31829b08;

  /// HaRu UI: 最长时长（秒）
  ///
  /// In zh, this message translates to:
  /// **'最长时长（秒）'**
  String get ui1965e2dd;

  /// HaRu UI: 最高可用
  ///
  /// In zh, this message translates to:
  /// **'最高可用'**
  String get ui72d8c6d5;

  /// HaRu UI: 最高评分
  ///
  /// In zh, this message translates to:
  /// **'最高评分'**
  String get ui646cc4af;

  /// HaRu UI: 月
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get ui7dbfe375;

  /// HaRu UI: 月份
  ///
  /// In zh, this message translates to:
  /// **'月份'**
  String get ui625d464f;

  /// HaRu UI: 有 {p0} 个订阅暂时无法继续读取。
  ///
  /// In zh, this message translates to:
  /// **'有 {p0} 个订阅暂时无法继续读取。'**
  String ui06e923cf(String p0);

  /// HaRu UI: 有 {p0} 个订阅暂时无法读取。
  ///
  /// In zh, this message translates to:
  /// **'有 {p0} 个订阅暂时无法读取。'**
  String ui24ed3263(String p0);

  /// HaRu UI: 服务名称
  ///
  /// In zh, this message translates to:
  /// **'服务名称'**
  String get ui7ee4b38a;

  /// HaRu UI: 服务器响应异常 ({p0})
  ///
  /// In zh, this message translates to:
  /// **'服务器响应异常 ({p0})'**
  String ui46b673b1(String p0);

  /// HaRu UI: 服务器返回了 HTTP {p0}。
  ///
  /// In zh, this message translates to:
  /// **'服务器返回了 HTTP {p0}。'**
  String ui21fa42fa(String p0);

  /// HaRu UI: 服务器返回了缺少目标地址的重定向。
  ///
  /// In zh, this message translates to:
  /// **'服务器返回了缺少目标地址的重定向。'**
  String get ui34f469a4;

  /// HaRu UI: 服务器重定向次数过多。
  ///
  /// In zh, this message translates to:
  /// **'服务器重定向次数过多。'**
  String get ui496de832;

  /// HaRu UI: 未命名播放列表
  ///
  /// In zh, this message translates to:
  /// **'未命名播放列表'**
  String get ui7f356142;

  /// HaRu UI: 未命名系列
  ///
  /// In zh, this message translates to:
  /// **'未命名系列'**
  String get ui441a34c3;

  /// HaRu UI: 未命名视频
  ///
  /// In zh, this message translates to:
  /// **'未命名视频'**
  String get ui10bbdc2d;

  /// HaRu UI: 未挂载
  ///
  /// In zh, this message translates to:
  /// **'未挂载'**
  String get ui0b0f8079;

  /// HaRu UI: 未排除任何{p0}
  ///
  /// In zh, this message translates to:
  /// **'未排除任何{p0}'**
  String ui1d2649c7(String p0);

  /// HaRu UI: 未注入
  ///
  /// In zh, this message translates to:
  /// **'未注入'**
  String get ui5134b0d1;

  /// HaRu UI: 未登录 Hanime
  ///
  /// In zh, this message translates to:
  /// **'未登录 Hanime'**
  String get ui6c16defb;

  /// HaRu UI: 未知翻译类型
  ///
  /// In zh, this message translates to:
  /// **'未知翻译类型'**
  String get ui2219a9fe;

  /// HaRu UI: 未知错误
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get ui3b6c4912;

  /// HaRu UI: 未获取到更新信息。
  ///
  /// In zh, this message translates to:
  /// **'未获取到更新信息。'**
  String get ui32a1bf89;

  /// HaRu UI: 未配置
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get ui73b71caa;

  /// HaRu UI: 未配置 API Key
  ///
  /// In zh, this message translates to:
  /// **'未配置 API Key'**
  String get ui440ed665;

  /// HaRu UI: 本地分类库
  ///
  /// In zh, this message translates to:
  /// **'本地分类库'**
  String get ui593a76ae;

  /// HaRu UI: 本地库
  ///
  /// In zh, this message translates to:
  /// **'本地库'**
  String get ui0760582c;

  /// HaRu UI: 本地数据库读写异常，请重试
  ///
  /// In zh, this message translates to:
  /// **'本地数据库读写异常，请重试'**
  String get ui12e85520;

  /// HaRu UI: 本地诊断日志
  ///
  /// In zh, this message translates to:
  /// **'本地诊断日志'**
  String get ui5af2b9c7;

  /// HaRu UI: 本地语言识别
  ///
  /// In zh, this message translates to:
  /// **'本地语言识别'**
  String get ui78d79e7d;

  /// HaRu UI: 本机
  ///
  /// In zh, this message translates to:
  /// **'本机'**
  String get ui42457eeb;

  /// HaRu UI: 本机下载
  ///
  /// In zh, this message translates to:
  /// **'本机下载'**
  String get ui609a0e8a;

  /// HaRu UI: 本机下载记录
  ///
  /// In zh, this message translates to:
  /// **'本机下载记录'**
  String get ui010aee81;

  /// HaRu UI: 来源
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get ui21a44385;

  /// HaRu UI: 构建时间
  ///
  /// In zh, this message translates to:
  /// **'构建时间'**
  String get ui458ff22a;

  /// HaRu UI: 构建模式
  ///
  /// In zh, this message translates to:
  /// **'构建模式'**
  String get ui06231f4e;

  /// HaRu UI: 查看 HaRu 与第三方 Flutter 依赖许可
  ///
  /// In zh, this message translates to:
  /// **'查看 HaRu 与第三方 Flutter 依赖许可'**
  String get ui29d7c1b1;

  /// HaRu UI: 查看 {p0} 则回复
  ///
  /// In zh, this message translates to:
  /// **'查看 {p0} 则回复'**
  String ui2489fa87(String p0);

  /// HaRu UI: 查看公开资料、上传内容和公开收藏
  ///
  /// In zh, this message translates to:
  /// **'查看公开资料、上传内容和公开收藏'**
  String get ui3c5ed424;

  /// HaRu UI: 查看公开资料、订阅和上传内容
  ///
  /// In zh, this message translates to:
  /// **'查看公开资料、订阅和上传内容'**
  String get ui39fa84e7;

  /// HaRu UI: 查看并复制不含凭据的运行环境摘要
  ///
  /// In zh, this message translates to:
  /// **'查看并复制不含凭据的运行环境摘要'**
  String get ui682b70e0;

  /// HaRu UI: 查看更多
  ///
  /// In zh, this message translates to:
  /// **'查看更多'**
  String get ui7c04d205;

  /// HaRu UI: 查看诊断信息
  ///
  /// In zh, this message translates to:
  /// **'查看诊断信息'**
  String get ui37042e79;

  /// HaRu UI: 标准视频列表布局
  ///
  /// In zh, this message translates to:
  /// **'标准视频列表布局'**
  String get ui7f5af178;

  /// HaRu UI: 标签
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get ui3d8dc836;

  /// HaRu UI: 标题
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get ui669643c5;

  /// HaRu UI: 标题、分类和标签可以分别选择显示原文、译文或双语。
  ///
  /// In zh, this message translates to:
  /// **'标题、分类和标签可以分别选择显示原文、译文或双语。'**
  String get ui04e99c7b;

  /// HaRu UI: 检查更新
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get ui308c78ab;

  /// HaRu UI: 检查更新失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败：{p0}'**
  String ui5822474f(String p0);

  /// HaRu UI: 检查更新超时，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'检查更新超时，请稍后重试。'**
  String get ui3535d913;

  /// HaRu UI: 模型列表拉取失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'模型列表拉取失败：{p0}'**
  String ui35ec3fa1(String p0);

  /// HaRu UI: 模型列表返回格式无效
  ///
  /// In zh, this message translates to:
  /// **'模型列表返回格式无效'**
  String get ui0acd808e;

  /// HaRu UI: 模型名
  ///
  /// In zh, this message translates to:
  /// **'模型名'**
  String get ui703ce28e;

  /// HaRu UI: 模糊视频封面
  ///
  /// In zh, this message translates to:
  /// **'模糊视频封面'**
  String get ui1375925f;

  /// HaRu UI: 欢迎回来，{p0}！已成功登录 Hanime。
  ///
  /// In zh, this message translates to:
  /// **'欢迎回来，{p0}！已成功登录 Hanime。'**
  String ui61cd3d84(String p0);

  /// HaRu UI: 正在下载
  ///
  /// In zh, this message translates to:
  /// **'正在下载'**
  String get ui43f69efd;

  /// HaRu UI: 正在下载 · {p0}
  ///
  /// In zh, this message translates to:
  /// **'正在下载 · {p0}'**
  String ui210fbca4(String p0);

  /// HaRu UI: 正在下载更新包
  ///
  /// In zh, this message translates to:
  /// **'正在下载更新包'**
  String get ui68d41e66;

  /// HaRu UI: 正在刷新视频地址…
  ///
  /// In zh, this message translates to:
  /// **'正在刷新视频地址…'**
  String get ui34d9a170;

  /// HaRu UI: 正在处理
  ///
  /// In zh, this message translates to:
  /// **'正在处理'**
  String get ui57036f5e;

  /// HaRu UI: 正在播放
  ///
  /// In zh, this message translates to:
  /// **'正在播放'**
  String get ui0d9565c5;

  /// HaRu UI: 正在播放媒体
  ///
  /// In zh, this message translates to:
  /// **'正在播放媒体'**
  String get ui1e85b6dc;

  /// HaRu UI: 正在等待 Hanime 页面加载…如果长时间无反应，请点重试。
  ///
  /// In zh, this message translates to:
  /// **'正在等待 Hanime 页面加载…如果长时间无反应，请点重试。'**
  String get ui1a19f33c;

  /// HaRu UI: 正在读取全部视频…
  ///
  /// In zh, this message translates to:
  /// **'正在读取全部视频…'**
  String get ui37674019;

  /// HaRu UI: 正在读取可用清晰度…
  ///
  /// In zh, this message translates to:
  /// **'正在读取可用清晰度…'**
  String get ui5323d64f;

  /// HaRu UI: 正在读取收藏状态
  ///
  /// In zh, this message translates to:
  /// **'正在读取收藏状态'**
  String get ui334203a0;

  /// HaRu UI: 正在读取日志信息…
  ///
  /// In zh, this message translates to:
  /// **'正在读取日志信息…'**
  String get ui0c3a23f3;

  /// HaRu UI: 正在读取最近更新…
  ///
  /// In zh, this message translates to:
  /// **'正在读取最近更新…'**
  String get ui6b2b15cb;

  /// HaRu UI: 正在读取最近更新（{p0}/{p1}）
  ///
  /// In zh, this message translates to:
  /// **'正在读取最近更新（{p0}/{p1}）'**
  String ui40cc44ec(String p0, String p1);

  /// HaRu UI: 正在读取点赞状态
  ///
  /// In zh, this message translates to:
  /// **'正在读取点赞状态'**
  String get ui23a76939;

  /// HaRu UI: 正在读取版本…
  ///
  /// In zh, this message translates to:
  /// **'正在读取版本…'**
  String get ui3016a852;

  /// HaRu UI: 正在读取稍后观看状态
  ///
  /// In zh, this message translates to:
  /// **'正在读取稍后观看状态'**
  String get ui0c4e429a;

  /// HaRu UI: 正在连接
  ///
  /// In zh, this message translates to:
  /// **'正在连接'**
  String get ui3de0c840;

  /// HaRu UI: 正在通过浏览器连接 Hanime…
  ///
  /// In zh, this message translates to:
  /// **'正在通过浏览器连接 Hanime…'**
  String get ui7629ef8e;

  /// HaRu UI: 此构建未配置 GitHub Releases 更新源。
  ///
  /// In zh, this message translates to:
  /// **'此构建未配置 GitHub Releases 更新源。'**
  String get ui108cc700;

  /// HaRu UI: 此类型不支持订阅。
  ///
  /// In zh, this message translates to:
  /// **'此类型不支持订阅。'**
  String get ui4ddaf211;

  /// HaRu UI: 此类型暂不支持在 App 内取消订阅。
  ///
  /// In zh, this message translates to:
  /// **'此类型暂不支持在 App 内取消订阅。'**
  String get ui4e1b0f19;

  /// HaRu UI: 此视频未提供可直接播放的 MP4 源。
  ///
  /// In zh, this message translates to:
  /// **'此视频未提供可直接播放的 MP4 源。'**
  String get ui3a0a0c97;

  /// HaRu UI: 此视频没有可下载的 MP4 源。
  ///
  /// In zh, this message translates to:
  /// **'此视频没有可下载的 MP4 源。'**
  String get ui02c5ad74;

  /// HaRu UI: 此视频源仍不可用，请重试刷新视频地址。
  ///
  /// In zh, this message translates to:
  /// **'此视频源仍不可用，请重试刷新视频地址。'**
  String get ui7cb7a0c5;

  /// HaRu UI: 每次询问
  ///
  /// In zh, this message translates to:
  /// **'每次询问'**
  String get ui51c846f1;

  /// HaRu UI: 没有保存完成文件的位置。
  ///
  /// In zh, this message translates to:
  /// **'没有保存完成文件的位置。'**
  String get ui68fbffba;

  /// HaRu UI: 没有匹配的品牌。
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的品牌。'**
  String get ui129bcb21;

  /// HaRu UI: 没有匹配的已加载内容。
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的已加载内容。'**
  String get ui13ed4ac5;

  /// HaRu UI: 没有匹配的标签。
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的标签。'**
  String get ui26ec4dbb;

  /// HaRu UI: 没有可导出的日志。
  ///
  ///
  /// In zh, this message translates to:
  /// **'没有可导出的日志。\n'**
  String get ui5198af87;

  /// HaRu UI: 没有可用的备用清晰度，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'没有可用的备用清晰度，请稍后重试。'**
  String get ui29c894b2;

  /// HaRu UI: 没有启用翻译服务。
  ///
  /// In zh, this message translates to:
  /// **'没有启用翻译服务。'**
  String get ui59f601fd;

  /// HaRu UI: 没有找到与“{p0}”匹配的{p1}。
  ///
  /// In zh, this message translates to:
  /// **'没有找到与“{p0}”匹配的{p1}。'**
  String ui61fe8d4a(String p0, String p1);

  /// HaRu UI: 没有找到匹配的{p0}。
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的{p0}。'**
  String ui02a64c6e(String p0);

  /// HaRu UI: 没有找到同时满足这些条件的视频。
  ///
  /// In zh, this message translates to:
  /// **'没有找到同时满足这些条件的视频。'**
  String get ui6143fb85;

  /// HaRu UI: 没有找到对应的本地标签译文或已学习标题译文。
  ///
  /// In zh, this message translates to:
  /// **'没有找到对应的本地标签译文或已学习标题译文。'**
  String get ui2aa03638;

  /// HaRu UI: 没有找到相关{p0}。
  ///
  /// In zh, this message translates to:
  /// **'没有找到相关{p0}。'**
  String ui394bbe87(String p0);

  /// HaRu UI: 没有找到符合条件的视频。
  ///
  /// In zh, this message translates to:
  /// **'没有找到符合条件的视频。'**
  String get ui335a4697;

  /// HaRu UI: 没有找到视频。
  ///
  /// In zh, this message translates to:
  /// **'没有找到视频。'**
  String get ui3c55278f;

  /// HaRu UI: 没有符合搜索和筛选条件的视频。
  ///
  /// In zh, this message translates to:
  /// **'没有符合搜索和筛选条件的视频。'**
  String get ui2855d008;

  /// HaRu UI: 没有符合条件的下载记录。
  ///
  /// In zh, this message translates to:
  /// **'没有符合条件的下载记录。'**
  String get ui1cbeb77a;

  /// HaRu UI: 没有符合条件的播放列表。
  ///
  /// In zh, this message translates to:
  /// **'没有符合条件的播放列表。'**
  String get ui3f6214e2;

  /// HaRu UI: 没有符合条件的本地库。
  ///
  /// In zh, this message translates to:
  /// **'没有符合条件的本地库。'**
  String get ui5bcb2c9b;

  /// HaRu UI: 没有符合条件的订阅。
  ///
  /// In zh, this message translates to:
  /// **'没有符合条件的订阅。'**
  String get ui3288b748;

  /// HaRu UI: 没有符合条件的译文。
  ///
  /// In zh, this message translates to:
  /// **'没有符合条件的译文。'**
  String get ui1408d9d3;

  /// HaRu UI: 没有返回可用模型
  ///
  /// In zh, this message translates to:
  /// **'没有返回可用模型'**
  String get ui3ca6cd4f;

  /// HaRu UI: 泡面番
  ///
  /// In zh, this message translates to:
  /// **'泡面番'**
  String get ui522cef73;

  /// HaRu UI: 泡麵番
  ///
  /// In zh, this message translates to:
  /// **'泡麵番'**
  String get ui0edc6509;

  /// HaRu UI: 注册账号
  ///
  /// In zh, this message translates to:
  /// **'注册账号'**
  String get ui0e0207cc;

  /// HaRu UI: 注册邮箱
  ///
  /// In zh, this message translates to:
  /// **'注册邮箱'**
  String get ui34dc8c2e;

  /// HaRu UI: 浅色
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get ui4782703e;

  /// HaRu UI: 测试连接
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get ui06cf3f13;

  /// HaRu UI: 浏览站点评分最高的视频
  ///
  /// In zh, this message translates to:
  /// **'浏览站点评分最高的视频'**
  String get ui1bdcacb9;

  /// HaRu UI: 深色
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get ui4e94fd7c;

  /// HaRu UI: 添加
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get ui68aa72b8;

  /// HaRu UI: 清晰度
  ///
  /// In zh, this message translates to:
  /// **'清晰度'**
  String get ui28b4fe80;

  /// HaRu UI: 清空
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get ui1226aec8;

  /// HaRu UI: 清空搜索历史？
  ///
  /// In zh, this message translates to:
  /// **'清空搜索历史？'**
  String get ui66d1872a;

  /// HaRu UI: 清除
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get ui3c5a0f54;

  /// HaRu UI: 清除图片缓存
  ///
  /// In zh, this message translates to:
  /// **'清除图片缓存'**
  String get ui1e1dc2c5;

  /// HaRu UI: 清除图片缓存失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'清除图片缓存失败：{p0}'**
  String ui198292d1(String p0);

  /// HaRu UI: 清除应用日志？
  ///
  /// In zh, this message translates to:
  /// **'清除应用日志？'**
  String get ui2b78b9a7;

  /// HaRu UI: 清除当前账号搜索历史
  ///
  /// In zh, this message translates to:
  /// **'清除当前账号搜索历史'**
  String get ui62aa01c1;

  /// HaRu UI: 清除搜索
  ///
  /// In zh, this message translates to:
  /// **'清除搜索'**
  String get ui04093a21;

  /// HaRu UI: 清除搜索历史失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'清除搜索历史失败：{p0}'**
  String ui21987264(String p0);

  /// HaRu UI: 清除搜索历史？
  ///
  /// In zh, this message translates to:
  /// **'清除搜索历史？'**
  String get ui03f9bc1e;

  /// HaRu UI: 清除播放进度失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'清除播放进度失败：{p0}'**
  String ui0e4abc92(String p0);

  /// HaRu UI: 清除日志
  ///
  /// In zh, this message translates to:
  /// **'清除日志'**
  String get ui2b43d71b;

  /// HaRu UI: 清除日志失败，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'清除日志失败，请稍后重试。'**
  String get ui1f517bea;

  /// HaRu UI: 清除条件
  ///
  /// In zh, this message translates to:
  /// **'清除条件'**
  String get ui47882249;

  /// HaRu UI: 点击返回应用
  ///
  /// In zh, this message translates to:
  /// **'点击返回应用'**
  String get ui21697b99;

  /// HaRu UI: 点赞
  ///
  /// In zh, this message translates to:
  /// **'点赞'**
  String get ui3273204a;

  /// HaRu UI: 点赞列表暂时为空。
  ///
  /// In zh, this message translates to:
  /// **'点赞列表暂时为空。'**
  String get ui6356f887;

  /// HaRu UI: 点赞状态读取失败，点击重试
  ///
  /// In zh, this message translates to:
  /// **'点赞状态读取失败，点击重试'**
  String get ui6dfa7544;

  /// HaRu UI: 点赞率 ≥ {p0}%
  ///
  /// In zh, this message translates to:
  /// **'点赞率 ≥ {p0}%'**
  String ui26b5101f(String p0);

  /// HaRu UI: 点赞率必须配合投票数判断，避免少量投票造成虚高。
  ///
  /// In zh, this message translates to:
  /// **'点赞率必须配合投票数判断，避免少量投票造成虚高。'**
  String get ui1894e352;

  /// HaRu UI: 点踩
  ///
  /// In zh, this message translates to:
  /// **'点踩'**
  String get ui4992052a;

  /// HaRu UI: 热门
  ///
  /// In zh, this message translates to:
  /// **'热门'**
  String get ui71e94df2;

  /// HaRu UI: 热门标签
  ///
  /// In zh, this message translates to:
  /// **'热门标签'**
  String get ui41d23f81;

  /// HaRu UI: 热门标签暂时不可用。
  ///
  /// In zh, this message translates to:
  /// **'热门标签暂时不可用。'**
  String get ui0e7f13ac;

  /// HaRu UI: 热门视频
  ///
  /// In zh, this message translates to:
  /// **'热门视频'**
  String get ui795ab7fb;

  /// HaRu UI: 煽动仇恨或恶意内容
  ///
  /// In zh, this message translates to:
  /// **'煽动仇恨或恶意内容'**
  String get ui0ac00f7c;

  /// HaRu UI: 煽動仇恨或惡意內容
  ///
  /// In zh, this message translates to:
  /// **'煽動仇恨或惡意內容'**
  String get ui173de99c;

  /// HaRu UI: 版本 {p0}+{p1}
  ///
  /// In zh, this message translates to:
  /// **'版本 {p0}+{p1}'**
  String ui326c0193(String p0, String p1);

  /// HaRu UI: 版本：{p0}
  ///
  /// In zh, this message translates to:
  /// **'版本：{p0}'**
  String ui3d81628e(String p0);

  /// HaRu UI: 生成包含诊断信息和最近日志的文本文件。
  ///
  /// In zh, this message translates to:
  /// **'生成包含诊断信息和最近日志的文本文件。'**
  String get ui4627f6e6;

  /// HaRu UI: 用户
  ///
  /// In zh, this message translates to:
  /// **'用户'**
  String get ui1be4cbb9;

  /// HaRu UI: 用户 ID 格式无效
  ///
  /// In zh, this message translates to:
  /// **'用户 ID 格式无效'**
  String get ui6bab46da;

  /// HaRu UI: 用户 ID：{p0}
  ///
  /// In zh, this message translates to:
  /// **'用户 ID：{p0}'**
  String ui2ff2035d(String p0);

  /// HaRu UI: 用户开始了更高优先级的操作
  ///
  /// In zh, this message translates to:
  /// **'用户开始了更高优先级的操作'**
  String get ui04f9f7a4;

  /// HaRu UI: 用户译文 {p0} 条。
  ///
  ///
  ///
  /// In zh, this message translates to:
  /// **'用户译文 {p0} 条。\n\n'**
  String ui07df625b(String p0);

  /// HaRu UI: 由网站验证身份并处理邮箱变更
  ///
  /// In zh, this message translates to:
  /// **'由网站验证身份并处理邮箱变更'**
  String get ui02ac0fa7;

  /// HaRu UI: 由网站验证身份并更新账号密码
  ///
  /// In zh, this message translates to:
  /// **'由网站验证身份并更新账号密码'**
  String get ui766b8c5d;

  /// HaRu UI: 界面语言
  ///
  /// In zh, this message translates to:
  /// **'界面语言'**
  String get ui6f51d88d;

  /// HaRu UI: 留空表示保留原密钥
  ///
  /// In zh, this message translates to:
  /// **'留空表示保留原密钥'**
  String get ui673b9a23;

  /// HaRu UI: 登录
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get ui3ad2af27;

  /// HaRu UI: 登录 Hanime
  ///
  /// In zh, this message translates to:
  /// **'登录 Hanime'**
  String get ui720f5c51;

  /// HaRu UI: 登录 Hanime 后参与评论
  ///
  /// In zh, this message translates to:
  /// **'登录 Hanime 后参与评论'**
  String get ui5d9071a1;

  /// HaRu UI: 登录 R34V 后参与评论
  ///
  /// In zh, this message translates to:
  /// **'登录 R34V 后参与评论'**
  String get ui1cb8175c;

  /// HaRu UI: 登录 Rule34Video
  ///
  /// In zh, this message translates to:
  /// **'登录 Rule34Video'**
  String get ui633ad687;

  /// HaRu UI: 登录 {p0}
  ///
  /// In zh, this message translates to:
  /// **'登录 {p0}'**
  String ui7b669835(String p0);

  /// HaRu UI: 登录后即可查看收藏、历史、播放列表和订阅。
  ///
  /// In zh, this message translates to:
  /// **'登录后即可查看收藏、历史、播放列表和订阅。'**
  String get ui50edd253;

  /// HaRu UI: 登录后即可查看点赞、稍后观看、历史、播放列表和订阅。
  ///
  /// In zh, this message translates to:
  /// **'登录后即可查看点赞、稍后观看、历史、播放列表和订阅。'**
  String get ui0b18f11a;

  /// HaRu UI: 登录后同步网站收藏、历史记录和订阅。
  ///
  /// In zh, this message translates to:
  /// **'登录后同步网站收藏、历史记录和订阅。'**
  String get ui6ddcc3eb;

  /// HaRu UI: 登录后同步网站点赞、稍后观看、播放列表和评论。
  ///
  /// In zh, this message translates to:
  /// **'登录后同步网站点赞、稍后观看、播放列表和评论。'**
  String get ui47765d07;

  /// HaRu UI: 登录后查看订阅内容
  ///
  /// In zh, this message translates to:
  /// **'登录后查看订阅内容'**
  String get ui18ff18c2;

  /// HaRu UI: 登录后，搜索历史会按账号安全保存。
  ///
  /// In zh, this message translates to:
  /// **'登录后，搜索历史会按账号安全保存。'**
  String get ui4bd42f4c;

  /// HaRu UI: 登录失败，请检查账号、密码或验证码要求。
  ///
  /// In zh, this message translates to:
  /// **'登录失败，请检查账号、密码或验证码要求。'**
  String get ui1179dcd5;

  /// HaRu UI: 登录失败，请检查账号和密码。
  ///
  /// In zh, this message translates to:
  /// **'登录失败，请检查账号和密码。'**
  String get ui5a4df1a7;

  /// HaRu UI: 登录状态已过期，请重新登录。
  ///
  /// In zh, this message translates to:
  /// **'登录状态已过期，请重新登录。'**
  String get ui7d58135d;

  /// HaRu UI: 目标语言
  ///
  /// In zh, this message translates to:
  /// **'目标语言'**
  String get ui257d2512;

  /// HaRu UI: 相关度
  ///
  /// In zh, this message translates to:
  /// **'相关度'**
  String get ui564ade2f;

  /// HaRu UI: 相关视频
  ///
  /// In zh, this message translates to:
  /// **'相关视频'**
  String get ui5e5057d9;

  /// HaRu UI: 确定
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get ui271e4b44;

  /// HaRu UI: 确定取消订阅“{p0}”吗？
  ///
  /// In zh, this message translates to:
  /// **'确定取消订阅“{p0}”吗？'**
  String ui5731dc83(String p0);

  /// HaRu UI: 确认删除
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get ui10bfd59a;

  /// HaRu UI: 确认批量删除？
  ///
  /// In zh, this message translates to:
  /// **'确认批量删除？'**
  String get ui23a1a099;

  /// HaRu UI: 确认新密码
  ///
  /// In zh, this message translates to:
  /// **'确认新密码'**
  String get ui79c740c7;

  /// HaRu UI: 票
  ///
  /// In zh, this message translates to:
  /// **'票'**
  String get ui22d867a3;

  /// HaRu UI: 票数最多
  ///
  /// In zh, this message translates to:
  /// **'票数最多'**
  String get ui3e2a2939;

  /// HaRu UI: 秒
  ///
  /// In zh, this message translates to:
  /// **'秒'**
  String get ui2cd19db3;

  /// HaRu UI: 移出此库
  ///
  /// In zh, this message translates to:
  /// **'移出此库'**
  String get ui07f3e573;

  /// HaRu UI: 移出此播放列表
  ///
  /// In zh, this message translates to:
  /// **'移出此播放列表'**
  String get ui332d29c7;

  /// HaRu UI: 移出稍后观看
  ///
  /// In zh, this message translates to:
  /// **'移出稍后观看'**
  String get ui3898a44a;

  /// HaRu UI: 移除失效记录
  ///
  /// In zh, this message translates to:
  /// **'移除失效记录'**
  String get ui3890123e;

  /// HaRu UI: 移除失效记录？
  ///
  /// In zh, this message translates to:
  /// **'移除失效记录？'**
  String get ui43f4c9b6;

  /// HaRu UI: 稍后观看
  ///
  /// In zh, this message translates to:
  /// **'稍后观看'**
  String get ui73f2e211;

  /// HaRu UI: 稍后观看列表暂时为空。
  ///
  /// In zh, this message translates to:
  /// **'稍后观看列表暂时为空。'**
  String get ui5d12e72e;

  /// HaRu UI: 稍后观看状态读取失败，点击重试
  ///
  /// In zh, this message translates to:
  /// **'稍后观看状态读取失败，点击重试'**
  String get ui6e62f819;

  /// HaRu UI: 稳定版
  ///
  /// In zh, this message translates to:
  /// **'稳定版'**
  String get ui3250d80e;

  /// HaRu UI: 站内消息
  ///
  /// In zh, this message translates to:
  /// **'站内消息'**
  String get ui68bc4e82;

  /// HaRu UI: 站点服务暂时不可用，请稍后重试
  ///
  /// In zh, this message translates to:
  /// **'站点服务暂时不可用，请稍后重试'**
  String get ui1becc780;

  /// HaRu UI: 等待下载
  ///
  /// In zh, this message translates to:
  /// **'等待下载'**
  String get ui2ced8087;

  /// HaRu UI: 等待重试
  ///
  /// In zh, this message translates to:
  /// **'等待重试'**
  String get ui106c1db7;

  /// HaRu UI: 筛选
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get ui373ece32;

  /// HaRu UI: 筛选与排序
  ///
  /// In zh, this message translates to:
  /// **'筛选与排序'**
  String get ui65b9a0f6;

  /// HaRu UI: 筛选仅覆盖已加载内容，继续下滑可加载更多
  ///
  /// In zh, this message translates to:
  /// **'筛选仅覆盖已加载内容，继续下滑可加载更多'**
  String get ui0ea0c5c7;

  /// HaRu UI: 筛选已加载的{p0}
  ///
  /// In zh, this message translates to:
  /// **'筛选已加载的{p0}'**
  String ui354b30cc(String p0);

  /// HaRu UI: 筛选播放列表
  ///
  /// In zh, this message translates to:
  /// **'筛选播放列表'**
  String get ui269190a8;

  /// HaRu UI: 筛选此库
  ///
  /// In zh, this message translates to:
  /// **'筛选此库'**
  String get ui72e0eba7;

  /// HaRu UI: 筛选视频
  ///
  /// In zh, this message translates to:
  /// **'筛选视频'**
  String get ui2fe9e03b;

  /// HaRu UI: 简介
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get ui78a24072;

  /// HaRu UI: 简体中文
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get ui36e4a35c;

  /// HaRu UI: 管理播放列表
  ///
  /// In zh, this message translates to:
  /// **'管理播放列表'**
  String get ui2f406a3c;

  /// HaRu UI: 类型
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get ui7aa38d36;

  /// HaRu UI: 精选库 {p0} 包含重复视频。
  ///
  /// In zh, this message translates to:
  /// **'精选库 {p0} 包含重复视频。'**
  String ui0dbe3ac7(String p0);

  /// HaRu UI: 精选库条目格式无效。
  ///
  /// In zh, this message translates to:
  /// **'精选库条目格式无效。'**
  String get ui3ae9eef9;

  /// HaRu UI: 精选库条目缺少必要字段。
  ///
  /// In zh, this message translates to:
  /// **'精选库条目缺少必要字段。'**
  String get ui6d95458c;

  /// HaRu UI: 精选库清单包含重复标识。
  ///
  /// In zh, this message translates to:
  /// **'精选库清单包含重复标识。'**
  String get ui082a7d52;

  /// HaRu UI: 精选库清单格式无效。
  ///
  /// In zh, this message translates to:
  /// **'精选库清单格式无效。'**
  String get ui05f173f7;

  /// HaRu UI: 精选库清单缺少版本或库列表。
  ///
  /// In zh, this message translates to:
  /// **'精选库清单缺少版本或库列表。'**
  String get ui48c2347b;

  /// HaRu UI: 精选视频条目格式无效。
  ///
  /// In zh, this message translates to:
  /// **'精选视频条目格式无效。'**
  String get ui45724236;

  /// HaRu UI: 精选视频条目缺少必要字段。
  ///
  /// In zh, this message translates to:
  /// **'精选视频条目缺少必要字段。'**
  String get ui3c28fff7;

  /// HaRu UI: 系列视频
  ///
  /// In zh, this message translates to:
  /// **'系列视频'**
  String get ui54ac0aa3;

  /// HaRu UI: 系统未授予公共下载目录写入权限。
  ///
  /// In zh, this message translates to:
  /// **'系统未授予公共下载目录写入权限。'**
  String get ui05a078da;

  /// HaRu UI: 系统未能将任务加入下载队列。
  ///
  /// In zh, this message translates to:
  /// **'系统未能将任务加入下载队列。'**
  String get ui21f76d12;

  /// HaRu UI: 系统未能重新加入下载任务。
  ///
  /// In zh, this message translates to:
  /// **'系统未能重新加入下载任务。'**
  String get ui111afc5c;

  /// HaRu UI: 系统阻止了本次安装，请检查「安装未知应用」权限。
  ///
  /// In zh, this message translates to:
  /// **'系统阻止了本次安装，请检查「安装未知应用」权限。'**
  String get ui3dbce44e;

  /// HaRu UI: 结束日期
  ///
  /// In zh, this message translates to:
  /// **'结束日期'**
  String get ui7344fe1b;

  /// HaRu UI: 结束日期不能早于开始日期
  ///
  /// In zh, this message translates to:
  /// **'结束日期不能早于开始日期'**
  String get ui7df2c519;

  /// HaRu UI: 继续
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get ui5cb65115;

  /// HaRu UI: 继续加载并查找
  ///
  /// In zh, this message translates to:
  /// **'继续加载并查找'**
  String get ui0487b957;

  /// HaRu UI: 继续向下滚动
  ///
  /// In zh, this message translates to:
  /// **'继续向下滚动'**
  String get ui16709544;

  /// HaRu UI: 继续向下滚动以加载更多
  ///
  /// In zh, this message translates to:
  /// **'继续向下滚动以加载更多'**
  String get ui75e19e47;

  /// HaRu UI: 继续手动填写
  ///
  /// In zh, this message translates to:
  /// **'继续手动填写'**
  String get ui4a3ada55;

  /// HaRu UI: 综合
  ///
  /// In zh, this message translates to:
  /// **'综合'**
  String get ui0e97bdd4;

  /// HaRu UI: 编辑
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get ui49512531;

  /// HaRu UI: 编辑播放列表
  ///
  /// In zh, this message translates to:
  /// **'编辑播放列表'**
  String get ui07922887;

  /// HaRu UI: 编辑翻译服务
  ///
  /// In zh, this message translates to:
  /// **'编辑翻译服务'**
  String get ui1d6b067d;

  /// HaRu UI: 编辑译文
  ///
  /// In zh, this message translates to:
  /// **'编辑译文'**
  String get ui0faaeb98;

  /// HaRu UI: 编辑账号资料
  ///
  /// In zh, this message translates to:
  /// **'编辑账号资料'**
  String get ui4232bd82;

  /// HaRu UI: 编辑资料
  ///
  /// In zh, this message translates to:
  /// **'编辑资料'**
  String get ui7d44f8fd;

  /// HaRu UI: 网站个人主页
  ///
  /// In zh, this message translates to:
  /// **'网站个人主页'**
  String get ui59c1fe85;

  /// HaRu UI: 网站收藏、历史和订阅以登录账号为边界；本地分类库保存在设备上，与账号无关。
  ///
  /// In zh, this message translates to:
  /// **'网站收藏、历史和订阅以登录账号为边界；本地分类库保存在设备上，与账号无关。'**
  String get ui166970fa;

  /// HaRu UI: 网站要求填写验证码，因此由系统浏览器完成提交
  ///
  /// In zh, this message translates to:
  /// **'网站要求填写验证码，因此由系统浏览器完成提交'**
  String get ui6d8a839a;

  /// HaRu UI: 网站观看历史还是空的。
  ///
  /// In zh, this message translates to:
  /// **'网站观看历史还是空的。'**
  String get ui52d40a61;

  /// HaRu UI: 网站退出请求失败，但本地登录状态已经清除。
  ///
  /// In zh, this message translates to:
  /// **'网站退出请求失败，但本地登录状态已经清除。'**
  String get ui49712caa;

  /// HaRu UI: 网站顺序
  ///
  /// In zh, this message translates to:
  /// **'网站顺序'**
  String get ui22be6add;

  /// HaRu UI: 网络播放策略
  ///
  /// In zh, this message translates to:
  /// **'网络播放策略'**
  String get ui5c5b8e6e;

  /// HaRu UI: 网络请求超时
  ///
  /// In zh, this message translates to:
  /// **'网络请求超时'**
  String get ui2d500e9d;

  /// HaRu UI: 网络请求超时，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'网络请求超时，请稍后重试。'**
  String get ui23b94735;

  /// HaRu UI: 网络请求遇到问题，请重试
  ///
  /// In zh, this message translates to:
  /// **'网络请求遇到问题，请重试'**
  String get ui3778b430;

  /// HaRu UI: 网络连接中断，请检查网络后重试。
  ///
  /// In zh, this message translates to:
  /// **'网络连接中断，请检查网络后重试。'**
  String get ui5d909650;

  /// HaRu UI: 网络连接失败，请检查网络是否畅通
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败，请检查网络是否畅通'**
  String get ui24c5d5a2;

  /// HaRu UI: 网络连接异常，请检查网络
  ///
  /// In zh, this message translates to:
  /// **'网络连接异常，请检查网络'**
  String get ui5717be7d;

  /// HaRu UI: 网络连接异常，请检查网络后重试
  ///
  /// In zh, this message translates to:
  /// **'网络连接异常，请检查网络后重试'**
  String get ui21d8799f;

  /// HaRu UI: 网络错误
  ///
  /// In zh, this message translates to:
  /// **'网络错误'**
  String get ui121f0e14;

  /// HaRu UI: 网页 / Google 账号登入
  ///
  /// In zh, this message translates to:
  /// **'网页 / Google 账号登入'**
  String get ui3ce8e370;

  /// HaRu UI: 翻译不能为空
  ///
  /// In zh, this message translates to:
  /// **'翻译不能为空'**
  String get ui7fe12441;

  /// HaRu UI: 翻译失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'翻译失败：{p0}'**
  String ui4c8d7732(String p0);

  /// HaRu UI: 翻译库
  ///
  /// In zh, this message translates to:
  /// **'翻译库'**
  String get ui20251330;

  /// HaRu UI: 翻译库包含不支持的目标语言：{p0}
  ///
  /// In zh, this message translates to:
  /// **'翻译库包含不支持的目标语言：{p0}'**
  String ui6053d6fa(String p0);

  /// HaRu UI: 翻译库包含长度异常的字段
  ///
  /// In zh, this message translates to:
  /// **'翻译库包含长度异常的字段'**
  String get ui3a3c90e9;

  /// HaRu UI: 翻译库文件不能超过 10 MB
  ///
  /// In zh, this message translates to:
  /// **'翻译库文件不能超过 10 MB'**
  String get ui2cec6aea;

  /// HaRu UI: 翻译库缺少 entries
  ///
  /// In zh, this message translates to:
  /// **'翻译库缺少 entries'**
  String get ui06ac6475;

  /// HaRu UI: 翻译库词条数量超过 100000 条
  ///
  /// In zh, this message translates to:
  /// **'翻译库词条数量超过 100000 条'**
  String get ui04eb7dc2;

  /// HaRu UI: 翻译库键字段包含非法字符
  ///
  /// In zh, this message translates to:
  /// **'翻译库键字段包含非法字符'**
  String get ui0250a335;

  /// HaRu UI: 翻译服务
  ///
  /// In zh, this message translates to:
  /// **'翻译服务'**
  String get ui0e144c39;

  /// HaRu UI: 翻译服务尚未配置
  ///
  /// In zh, this message translates to:
  /// **'翻译服务尚未配置'**
  String get ui071ebcfb;

  /// HaRu UI: 翻译目标语言
  ///
  /// In zh, this message translates to:
  /// **'翻译目标语言'**
  String get ui4e721b57;

  /// HaRu UI: 翻译设置
  ///
  /// In zh, this message translates to:
  /// **'翻译设置'**
  String get ui7312260a;

  /// HaRu UI: 翻译资产不是 JSON 对象：{p0}
  ///
  /// In zh, this message translates to:
  /// **'翻译资产不是 JSON 对象：{p0}'**
  String ui6f7c8396(String p0);

  /// HaRu UI: 自动
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get ui42682f0b;

  /// HaRu UI: 自动安装更新包需要「安装未知应用」权限。请在系统设置中允许 HaRu 安装应用后返回。
  ///
  /// In zh, this message translates to:
  /// **'自动安装更新包需要「安装未知应用」权限。请在系统设置中允许 HaRu 安装应用后返回。'**
  String get ui653fb447;

  /// HaRu UI: 自动或手动翻译时，每次只发送当前标题、标签或分类。服务按当前顺序依次尝试，失败后自动使用下一项。建议优先使用 AI 翻译，结果通常更自然、准确。
  ///
  /// In zh, this message translates to:
  /// **'自动或手动翻译时，每次只发送当前标题、标签或分类。服务按当前顺序依次尝试，失败后自动使用下一项。建议优先使用 AI 翻译，结果通常更自然、准确。'**
  String get ui3a3ee33c;

  /// HaRu UI: 自动翻译
  ///
  /// In zh, this message translates to:
  /// **'自动翻译'**
  String get ui4e37cc82;

  /// HaRu UI: 自定义…
  ///
  /// In zh, this message translates to:
  /// **'自定义…'**
  String get ui1a28517b;

  /// HaRu UI: 自定义日期
  ///
  /// In zh, this message translates to:
  /// **'自定义日期'**
  String get ui401af108;

  /// HaRu UI: 自定义时长
  ///
  /// In zh, this message translates to:
  /// **'自定义时长'**
  String get ui1b64dd4b;

  /// HaRu UI: 自定义筛选范围无效。
  ///
  /// In zh, this message translates to:
  /// **'自定义筛选范围无效。'**
  String get ui50983ec8;

  /// HaRu UI: 艺术家
  ///
  /// In zh, this message translates to:
  /// **'艺术家'**
  String get ui1d2c54c2;

  /// HaRu UI: 艺术家排行榜
  ///
  /// In zh, this message translates to:
  /// **'艺术家排行榜'**
  String get ui273d81af;

  /// HaRu UI: 艺术家订阅
  ///
  /// In zh, this message translates to:
  /// **'艺术家订阅'**
  String get ui2947cbbe;

  /// HaRu UI: 节省流量
  ///
  /// In zh, this message translates to:
  /// **'节省流量'**
  String get ui296bcd5e;

  /// HaRu UI: 获取播放列表安全令牌失败，请刷新后重试。
  ///
  /// In zh, this message translates to:
  /// **'获取播放列表安全令牌失败，请刷新后重试。'**
  String get ui0559c77a;

  /// HaRu UI: 萬
  ///
  /// In zh, this message translates to:
  /// **'萬'**
  String get ui3451174b;

  /// HaRu UI: 裏番
  ///
  /// In zh, this message translates to:
  /// **'裏番'**
  String get ui5c249ba5;

  /// HaRu UI: 觀看次數
  ///
  /// In zh, this message translates to:
  /// **'觀看次數'**
  String get ui38959118;

  /// HaRu UI: 观看次数
  ///
  /// In zh, this message translates to:
  /// **'观看次数'**
  String get ui67fc978a;

  /// HaRu UI: 视频
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get ui7f179fc8;

  /// HaRu UI: 视频 {p0}
  ///
  /// In zh, this message translates to:
  /// **'视频 {p0}'**
  String ui248185b4(String p0);

  /// HaRu UI: 视频保存路径：Download/Flule34
  ///
  /// In zh, this message translates to:
  /// **'视频保存路径：Download/Flule34'**
  String get ui4fbae4c2;

  /// HaRu UI: 视频可能已保存到 Download/Flule34，但应用未能确认其位置，请在系统文件管理器中查看。
  ///
  /// In zh, this message translates to:
  /// **'视频可能已保存到 Download/Flule34，但应用未能确认其位置，请在系统文件管理器中查看。'**
  String get ui1f59ee3b;

  /// HaRu UI: 视频地址已连续刷新多次仍无法播放，请稍后手动重试。
  ///
  /// In zh, this message translates to:
  /// **'视频地址已连续刷新多次仍无法播放，请稍后手动重试。'**
  String get ui538cdd02;

  /// HaRu UI: 视频操作
  ///
  /// In zh, this message translates to:
  /// **'视频操作'**
  String get ui37bdf9f3;

  /// HaRu UI: 视频数量
  ///
  /// In zh, this message translates to:
  /// **'视频数量'**
  String get ui604372e8;

  /// HaRu UI: 视频时长
  ///
  /// In zh, this message translates to:
  /// **'视频时长'**
  String get ui7b794d8a;

  /// HaRu UI: 视频源不能为空
  ///
  /// In zh, this message translates to:
  /// **'视频源不能为空'**
  String get ui63929b8d;

  /// HaRu UI: 视频直接写入所选公共目录；默认目录为 Downloads/Flule34，可从“我的 → 下载”右上角进入设置。
  ///
  /// In zh, this message translates to:
  /// **'视频直接写入所选公共目录；默认目录为 Downloads/Flule34，可从“我的 → 下载”右上角进入设置。'**
  String get ui6b6d2d3c;

  /// HaRu UI: 视频详情响应异常，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'视频详情响应异常，请稍后重试。'**
  String get ui0ee94f25;

  /// HaRu UI: 视频预览
  ///
  /// In zh, this message translates to:
  /// **'视频预览'**
  String get ui6fbc2348;

  /// HaRu UI: 解锁控件
  ///
  /// In zh, this message translates to:
  /// **'解锁控件'**
  String get ui7b8f2379;

  /// HaRu UI: 订阅
  ///
  /// In zh, this message translates to:
  /// **'订阅'**
  String get ui6e7502fd;

  /// HaRu UI: 订阅的分类、艺术家或用户暂时没有可展示的视频。
  ///
  /// In zh, this message translates to:
  /// **'订阅的分类、艺术家或用户暂时没有可展示的视频。'**
  String get ui7d39567a;

  /// HaRu UI: 订阅的艺术家暂时没有新视频。
  ///
  /// In zh, this message translates to:
  /// **'订阅的艺术家暂时没有新视频。'**
  String get ui42e78a20;

  /// HaRu UI: 订阅页布局
  ///
  /// In zh, this message translates to:
  /// **'订阅页布局'**
  String get ui4c54789e;

  /// HaRu UI: 订阅频道会汇总你在网站订阅的分类、艺术家、用户和播放列表。
  ///
  /// In zh, this message translates to:
  /// **'订阅频道会汇总你在网站订阅的分类、艺术家、用户和播放列表。'**
  String get ui40acc969;

  /// HaRu UI: 记忆播放进度
  ///
  /// In zh, this message translates to:
  /// **'记忆播放进度'**
  String get ui3c79fc19;

  /// HaRu UI: 设为私密
  ///
  /// In zh, this message translates to:
  /// **'设为私密'**
  String get ui5ab2c3c2;

  /// HaRu UI: 设备
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get ui592e7edb;

  /// HaRu UI: 设备存储空间不足，无法安装更新包。
  ///
  /// In zh, this message translates to:
  /// **'设备存储空间不足，无法安装更新包。'**
  String get ui2e92dd76;

  /// HaRu UI: 访问受限，可能需要安全验证
  ///
  /// In zh, this message translates to:
  /// **'访问受限，可能需要安全验证'**
  String get ui17add25c;

  /// HaRu UI: 评分最高
  ///
  /// In zh, this message translates to:
  /// **'评分最高'**
  String get ui11313487;

  /// HaRu UI: 评论
  ///
  /// In zh, this message translates to:
  /// **'评论'**
  String get ui491e642c;

  /// HaRu UI: 评论内容不能为空。
  ///
  /// In zh, this message translates to:
  /// **'评论内容不能为空。'**
  String get ui22cd66c8;

  /// HaRu UI: 评论加载失败，点击重试
  ///
  /// In zh, this message translates to:
  /// **'评论加载失败，点击重试'**
  String get ui7d9b7107;

  /// HaRu UI: 评论已发表。
  ///
  /// In zh, this message translates to:
  /// **'评论已发表。'**
  String get ui005f2e8d;

  /// HaRu UI: 评论已提交，审核通过后展示。
  ///
  /// In zh, this message translates to:
  /// **'评论已提交，审核通过后展示。'**
  String get ui761f4205;

  /// HaRu UI: 诊断信息
  ///
  /// In zh, this message translates to:
  /// **'诊断信息'**
  String get ui3ce65beb;

  /// HaRu UI: 诊断信息已复制。
  ///
  /// In zh, this message translates to:
  /// **'诊断信息已复制。'**
  String get ui442a175d;

  /// HaRu UI: 译文
  ///
  /// In zh, this message translates to:
  /// **'译文'**
  String get ui0a2256ac;

  /// HaRu UI: 译文不能为空
  ///
  /// In zh, this message translates to:
  /// **'译文不能为空'**
  String get ui5e9e6941;

  /// HaRu UI: 该客户端已被关闭，无法发起请求。
  ///
  /// In zh, this message translates to:
  /// **'该客户端已被关闭，无法发起请求。'**
  String get ui139f12da;

  /// HaRu UI: 该播放列表已不存在，请重新选择。
  ///
  /// In zh, this message translates to:
  /// **'该播放列表已不存在，请重新选择。'**
  String get ui13ecda96;

  /// HaRu UI: 该本地库已不存在，请重新选择。
  ///
  /// In zh, this message translates to:
  /// **'该本地库已不存在，请重新选择。'**
  String get ui17f975b3;

  /// HaRu UI: 该版本没有可下载的安装包。
  ///
  /// In zh, this message translates to:
  /// **'该版本没有可下载的安装包。'**
  String get ui6ebae107;

  /// HaRu UI: 该版本没有可下载的安装包，已打开 GitHub 发布页。
  ///
  /// In zh, this message translates to:
  /// **'该版本没有可下载的安装包，已打开 GitHub 发布页。'**
  String get ui5accb58a;

  /// HaRu UI: 该类型不允许翻译
  ///
  /// In zh, this message translates to:
  /// **'该类型不允许翻译'**
  String get ui244129bf;

  /// HaRu UI: 语言显示模式
  ///
  /// In zh, this message translates to:
  /// **'语言显示模式'**
  String get ui52575ad3;

  /// HaRu UI: 说明
  ///
  /// In zh, this message translates to:
  /// **'说明'**
  String get ui16d86fec;

  /// HaRu UI: 请先填写 API Key
  ///
  /// In zh, this message translates to:
  /// **'请先填写 API Key'**
  String get ui4e258c29;

  /// HaRu UI: 请先填写有效基址。
  ///
  /// In zh, this message translates to:
  /// **'请先填写有效基址。'**
  String get ui7894fed1;

  /// HaRu UI: 请先登录 Hanime
  ///
  /// In zh, this message translates to:
  /// **'请先登录 Hanime'**
  String get ui19e258a9;

  /// HaRu UI: 请先登录 Hanime 账号。
  ///
  /// In zh, this message translates to:
  /// **'请先登录 Hanime 账号。'**
  String get ui3ee081eb;

  /// HaRu UI: 请先登录后再使用此功能。
  ///
  /// In zh, this message translates to:
  /// **'请先登录后再使用此功能。'**
  String get ui57f971fd;

  /// HaRu UI: 请在网页中完成验证，成功后会自动返回。
  ///
  /// In zh, this message translates to:
  /// **'请在网页中完成验证，成功后会自动返回。'**
  String get ui7ce74a5f;

  /// HaRu UI: 请完整填写名称、基址、模型和密钥。
  ///
  /// In zh, this message translates to:
  /// **'请完整填写名称、基址、模型和密钥。'**
  String get ui190ff633;

  /// HaRu UI: 请求失败
  ///
  /// In zh, this message translates to:
  /// **'请求失败'**
  String get ui2033b3c1;

  /// HaRu UI: 请求失败，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'请求失败，请稍后重试。'**
  String get ui673534a9;

  /// HaRu UI: 请求失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'请求失败：{p0}'**
  String ui64ba2be4(String p0);

  /// HaRu UI: 请求已取消
  ///
  /// In zh, this message translates to:
  /// **'请求已取消'**
  String get ui0d97efea;

  /// HaRu UI: 请求的内容不存在或已被删除
  ///
  /// In zh, this message translates to:
  /// **'请求的内容不存在或已被删除'**
  String get ui4bc1c631;

  /// HaRu UI: 请求超时，请重试
  ///
  /// In zh, this message translates to:
  /// **'请求超时，请重试'**
  String get ui3a579d8a;

  /// HaRu UI: 请求过于频繁，服务器建议 {p0} 分钟后再试
  ///
  /// In zh, this message translates to:
  /// **'请求过于频繁，服务器建议 {p0} 分钟后再试'**
  String ui17d9c651(String p0);

  /// HaRu UI: 请求过于频繁，服务器建议 {p0} 秒后再试
  ///
  /// In zh, this message translates to:
  /// **'请求过于频繁，服务器建议 {p0} 秒后再试'**
  String ui72adb9a6(String p0);

  /// HaRu UI: 请求过于频繁，请稍后重试
  ///
  /// In zh, this message translates to:
  /// **'请求过于频繁，请稍后重试'**
  String get ui43188d72;

  /// HaRu UI: 请至少输入 2 个字符。
  ///
  /// In zh, this message translates to:
  /// **'请至少输入 2 个字符。'**
  String get ui61ca1aa4;

  /// HaRu UI: 请输入 0 至 36000 的整数
  ///
  /// In zh, this message translates to:
  /// **'请输入 0 至 36000 的整数'**
  String get ui7d47ba9d;

  /// HaRu UI: 请输入密码。
  ///
  /// In zh, this message translates to:
  /// **'请输入密码。'**
  String get ui61cb4e40;

  /// HaRu UI: 请输入注册邮箱。
  ///
  /// In zh, this message translates to:
  /// **'请输入注册邮箱。'**
  String get ui196453a1;

  /// HaRu UI: 请返回“我的”页面登录 Hanime 账号。
  ///
  /// In zh, this message translates to:
  /// **'请返回“我的”页面登录 Hanime 账号。'**
  String get ui742d2222;

  /// HaRu UI: 请返回“我的”页面登录后查看账号信息。
  ///
  /// In zh, this message translates to:
  /// **'请返回“我的”页面登录后查看账号信息。'**
  String get ui77044f29;

  /// HaRu UI: 账号与媒体库
  ///
  /// In zh, this message translates to:
  /// **'账号与媒体库'**
  String get ui6447b2e3;

  /// HaRu UI: 账号中还没有播放列表。
  ///
  /// In zh, this message translates to:
  /// **'账号中还没有播放列表。'**
  String get ui6527aff1;

  /// HaRu UI: 账号和密码不能为空。
  ///
  /// In zh, this message translates to:
  /// **'账号和密码不能为空。'**
  String get ui65413ec5;

  /// HaRu UI: 账号状态发生变化
  ///
  /// In zh, this message translates to:
  /// **'账号状态发生变化'**
  String get ui2d477648;

  /// HaRu UI: 账号资料已更新。
  ///
  /// In zh, this message translates to:
  /// **'账号资料已更新。'**
  String get ui04e867ba;

  /// HaRu UI: 质量条件
  ///
  /// In zh, this message translates to:
  /// **'质量条件'**
  String get ui4f0bb3b1;

  /// HaRu UI: 资料加载失败，重试
  ///
  /// In zh, this message translates to:
  /// **'资料加载失败，重试'**
  String get ui5e2feb59;

  /// HaRu UI: 跟随界面语言
  ///
  /// In zh, this message translates to:
  /// **'跟随界面语言'**
  String get ui5236b1c3;

  /// HaRu UI: 跟随系统
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get ui1c47ee05;

  /// HaRu UI: 跳过 {p0}，
  ///
  /// In zh, this message translates to:
  /// **'跳过 {p0}，'**
  String ui76da0fc0(String p0);

  /// HaRu UI: 轮询
  ///
  /// In zh, this message translates to:
  /// **'轮询'**
  String get ui6c5a7de5;

  /// HaRu UI: 过去 1 周
  ///
  /// In zh, this message translates to:
  /// **'过去 1 周'**
  String get ui739c6fd6;

  /// HaRu UI: 过去 1 年
  ///
  /// In zh, this message translates to:
  /// **'过去 1 年'**
  String get ui5fd87a82;

  /// HaRu UI: 过去 1 月
  ///
  /// In zh, this message translates to:
  /// **'过去 1 月'**
  String get ui431df5d6;

  /// HaRu UI: 过去 2 天
  ///
  /// In zh, this message translates to:
  /// **'过去 2 天'**
  String get ui759f4739;

  /// HaRu UI: 过去 24 小时
  ///
  /// In zh, this message translates to:
  /// **'过去 24 小时'**
  String get ui7790bf0c;

  /// HaRu UI: 过去 3 月
  ///
  /// In zh, this message translates to:
  /// **'过去 3 月'**
  String get ui0a322b08;

  /// HaRu UI: 过滤品牌…
  ///
  /// In zh, this message translates to:
  /// **'过滤品牌…'**
  String get ui1c3504bd;

  /// HaRu UI: 过滤标签…
  ///
  /// In zh, this message translates to:
  /// **'过滤标签…'**
  String get ui1863f57b;

  /// HaRu UI: 返回
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get ui58a37252;

  /// HaRu UI: 返回了空译文
  ///
  /// In zh, this message translates to:
  /// **'返回了空译文'**
  String get ui3caf8ced;

  /// HaRu UI: 返回首页
  ///
  /// In zh, this message translates to:
  /// **'返回首页'**
  String get ui0a98d7f2;

  /// HaRu UI: 还没有下载任务。
  ///
  /// In zh, this message translates to:
  /// **'还没有下载任务。'**
  String get ui10524b4c;

  /// HaRu UI: 还没有搜索记录。
  ///
  /// In zh, this message translates to:
  /// **'还没有搜索记录。'**
  String get ui6e7397b9;

  /// HaRu UI: 还没有播放列表。
  ///
  /// In zh, this message translates to:
  /// **'还没有播放列表。'**
  String get ui5c800f01;

  /// HaRu UI: 还没有播放列表，可先新建一个。
  ///
  /// In zh, this message translates to:
  /// **'还没有播放列表，可先新建一个。'**
  String get ui58052679;

  /// HaRu UI: 还没有本地库
  ///
  /// In zh, this message translates to:
  /// **'还没有本地库'**
  String get ui71607183;

  /// HaRu UI: 还没有订阅内容。
  ///
  /// In zh, this message translates to:
  /// **'还没有订阅内容。'**
  String get ui7a38235f;

  /// HaRu UI: 还没有评论。
  ///
  /// In zh, this message translates to:
  /// **'还没有评论。'**
  String get ui460dc5ac;

  /// HaRu UI: 这个上传者还没有公开视频。
  ///
  /// In zh, this message translates to:
  /// **'这个上传者还没有公开视频。'**
  String get ui2f767daa;

  /// HaRu UI: 这个播放列表暂时没有视频。
  ///
  /// In zh, this message translates to:
  /// **'这个播放列表暂时没有视频。'**
  String get ui4d146290;

  /// HaRu UI: 这个播放列表里还没有视频。
  ///
  /// In zh, this message translates to:
  /// **'这个播放列表里还没有视频。'**
  String get ui3d2b959e;

  /// HaRu UI: 这个本地库里还没有视频。
  ///
  /// In zh, this message translates to:
  /// **'这个本地库里还没有视频。'**
  String get ui1543885f;

  /// HaRu UI: 这个订阅目前没有可显示的视频。
  ///
  /// In zh, this message translates to:
  /// **'这个订阅目前没有可显示的视频。'**
  String get ui08dc5995;

  /// HaRu UI: 这个集合里暂时没有视频。
  ///
  /// In zh, this message translates to:
  /// **'这个集合里暂时没有视频。'**
  String get ui0432dab5;

  /// HaRu UI: 这个频道暂时没有视频。
  ///
  /// In zh, this message translates to:
  /// **'这个频道暂时没有视频。'**
  String get ui6ad274d1;

  /// HaRu UI: 进入全屏时横屏
  ///
  /// In zh, this message translates to:
  /// **'进入全屏时横屏'**
  String get ui6c1512dd;

  /// HaRu UI: 进度
  ///
  /// In zh, this message translates to:
  /// **'进度'**
  String get ui231a13c4;

  /// HaRu UI: 连接失败：{p0}
  ///
  /// In zh, this message translates to:
  /// **'连接失败：{p0}'**
  String ui340178b5(String p0);

  /// HaRu UI: 连接超时，请检查网络设置后重试
  ///
  /// In zh, this message translates to:
  /// **'连接超时，请检查网络设置后重试'**
  String get ui2c70d970;

  /// HaRu UI: 退出
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get ui15cf6bb2;

  /// HaRu UI: 退出 Hanime 登录？
  ///
  /// In zh, this message translates to:
  /// **'退出 Hanime 登录？'**
  String get ui0fc3c7d8;

  /// HaRu UI: 退出全屏
  ///
  /// In zh, this message translates to:
  /// **'退出全屏'**
  String get ui61f69587;

  /// HaRu UI: 退出当前账号
  ///
  /// In zh, this message translates to:
  /// **'退出当前账号'**
  String get ui27d0dda9;

  /// HaRu UI: 退出登录
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get ui60423290;

  /// HaRu UI: 退出登录？
  ///
  /// In zh, this message translates to:
  /// **'退出登录？'**
  String get ui0c4a5e14;

  /// HaRu UI: 选择一个分类开始浏览，也可以直接在上方输入关键词搜索。
  ///
  /// In zh, this message translates to:
  /// **'选择一个分类开始浏览，也可以直接在上方输入关键词搜索。'**
  String get ui736d6f73;

  /// HaRu UI: 选择下载清晰度
  ///
  /// In zh, this message translates to:
  /// **'选择下载清晰度'**
  String get ui1d37ed9d;

  /// HaRu UI: 选择当前结果
  ///
  /// In zh, this message translates to:
  /// **'选择当前结果'**
  String get ui38e27fe6;

  /// HaRu UI: 选择本地库
  ///
  /// In zh, this message translates to:
  /// **'选择本地库'**
  String get ui63947462;

  /// HaRu UI: 选择模型
  ///
  /// In zh, this message translates to:
  /// **'选择模型'**
  String get ui2bbcf0c4;

  /// HaRu UI: 通过配置的 GitHub Releases 源检查
  ///
  /// In zh, this message translates to:
  /// **'通过配置的 GitHub Releases 源检查'**
  String get ui5b975d06;

  /// HaRu UI: 週
  ///
  /// In zh, this message translates to:
  /// **'週'**
  String get ui650c8807;

  /// HaRu UI: 邮箱
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get ui441fd1bc;

  /// HaRu UI: 邮箱（可选）
  ///
  /// In zh, this message translates to:
  /// **'邮箱（可选）'**
  String get ui359a4400;

  /// HaRu UI: 部分自动补全暂时不可用。
  ///
  /// In zh, this message translates to:
  /// **'部分自动补全暂时不可用。'**
  String get ui273538ab;

  /// HaRu UI: 部分订阅暂时无法读取，请稍后重试。
  ///
  /// In zh, this message translates to:
  /// **'部分订阅暂时无法读取，请稍后重试。'**
  String get ui5e31cf42;

  /// HaRu UI: 里番
  ///
  /// In zh, this message translates to:
  /// **'里番'**
  String get ui40cbba27;

  /// HaRu UI: 重命名
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get ui37f64133;

  /// HaRu UI: 重命名本地库
  ///
  /// In zh, this message translates to:
  /// **'重命名本地库'**
  String get ui6fd9a2aa;

  /// HaRu UI: 重新下载
  ///
  /// In zh, this message translates to:
  /// **'重新下载'**
  String get ui68e799c1;

  /// HaRu UI: 重新检查
  ///
  /// In zh, this message translates to:
  /// **'重新检查'**
  String get ui3161da01;

  /// HaRu UI: 重置
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get ui611079ce;

  /// HaRu UI: 重试
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get ui3e06d854;

  /// HaRu UI: 重试刷新
  ///
  /// In zh, this message translates to:
  /// **'重试刷新'**
  String get ui2fc2172a;

  /// HaRu UI: 重试加载下一页
  ///
  /// In zh, this message translates to:
  /// **'重试加载下一页'**
  String get ui1f5c932b;

  /// HaRu UI: 锁定控件
  ///
  /// In zh, this message translates to:
  /// **'锁定控件'**
  String get ui4a255d3c;

  /// HaRu UI: 长按视频封面预览
  ///
  /// In zh, this message translates to:
  /// **'长按视频封面预览'**
  String get ui4e1780ec;

  /// HaRu UI: 随机
  ///
  /// In zh, this message translates to:
  /// **'随机'**
  String get ui06efd73d;

  /// HaRu UI: 隐私与数据
  ///
  /// In zh, this message translates to:
  /// **'隐私与数据'**
  String get ui5d3798d3;

  /// HaRu UI: 隐私说明
  ///
  /// In zh, this message translates to:
  /// **'隐私说明'**
  String get ui249b111a;

  /// HaRu UI: 隐私说明：日志已自动脱敏，发送前仍建议自行检查。
  ///
  /// In zh, this message translates to:
  /// **'隐私说明：日志已自动脱敏，发送前仍建议自行检查。'**
  String get ui1c5806b0;

  /// HaRu UI: 隐藏密码
  ///
  /// In zh, this message translates to:
  /// **'隐藏密码'**
  String get ui4b4e6624;

  /// HaRu UI: 需要安装权限
  ///
  /// In zh, this message translates to:
  /// **'需要安装权限'**
  String get ui36eeedcb;

  /// HaRu UI: 需要通知权限才能可靠显示后台下载进度。
  ///
  /// In zh, this message translates to:
  /// **'需要通知权限才能可靠显示后台下载进度。'**
  String get ui25621c61;

  /// HaRu UI: 音乐
  ///
  /// In zh, this message translates to:
  /// **'音乐'**
  String get ui2555aad7;

  /// HaRu UI: 音量 {p0}%
  ///
  /// In zh, this message translates to:
  /// **'音量 {p0}%'**
  String ui0727f3bc(String p0);

  /// HaRu UI: 页面不存在
  ///
  /// In zh, this message translates to:
  /// **'页面不存在'**
  String get ui0fe51264;

  /// HaRu UI: 页面加载失败，可以点重试。
  ///
  /// In zh, this message translates to:
  /// **'页面加载失败，可以点重试。'**
  String get ui7746148e;

  /// HaRu UI: 页面完成
  ///
  /// In zh, this message translates to:
  /// **'页面完成'**
  String get ui17a3b28f;

  /// HaRu UI: 顺序播放
  ///
  /// In zh, this message translates to:
  /// **'顺序播放'**
  String get ui7f532d14;

  /// HaRu UI: 预加载服务已销毁
  ///
  /// In zh, this message translates to:
  /// **'预加载服务已销毁'**
  String get ui1ebb446b;

  /// HaRu UI: 预发布版
  ///
  /// In zh, this message translates to:
  /// **'预发布版'**
  String get ui73db46a3;

  /// HaRu UI: 频道
  ///
  /// In zh, this message translates to:
  /// **'频道'**
  String get ui17cde1d0;

  /// HaRu UI: 首页、搜索和媒体库的视频卡片会模糊显示封面。
  ///
  /// In zh, this message translates to:
  /// **'首页、搜索和媒体库的视频卡片会模糊显示封面。'**
  String get ui75c36c5d;

  /// HaRu UI: 首页默认内容取向
  ///
  /// In zh, this message translates to:
  /// **'首页默认内容取向'**
  String get ui11750af9;

  /// HaRu UI: 高评分
  ///
  /// In zh, this message translates to:
  /// **'高评分'**
  String get ui669768f7;

  /// HaRu UI: 高评分视频
  ///
  /// In zh, this message translates to:
  /// **'高评分视频'**
  String get ui1773f316;

  /// HaRu UI: 默认排序
  ///
  /// In zh, this message translates to:
  /// **'默认排序'**
  String get ui669c4c11;

  /// HaRu UI: 默认播放清晰度
  ///
  /// In zh, this message translates to:
  /// **'默认播放清晰度'**
  String get ui349affc5;

  /// HaRu UI: 默认顺序
  ///
  /// In zh, this message translates to:
  /// **'默认顺序'**
  String get ui41526a4f;

  /// HaRu UI: （API {p0}、用户 {p1}）；
  ///
  /// In zh, this message translates to:
  /// **'（API {p0}、用户 {p1}）；'**
  String ui5c240b03(String p0, String p1);

  /// HaRu UI: （精选）
  ///
  /// In zh, this message translates to:
  /// **'（精选）'**
  String get ui2102bc09;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
