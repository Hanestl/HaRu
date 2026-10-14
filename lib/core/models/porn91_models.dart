import 'package:flutter/foundation.dart';

/// 91porn 站点的内容分类。
///
/// 取值来自站点 `v.php?category=<code>` 导航（实测 2026-10）。
/// 站点会按 `Accept-Language` 返回英文导航文案，因此标签由 App 侧给出，
/// 不直接采用页面文本。
///
/// 导航里的 `category=hd` **不在**此列：它实测恒为空列表（两个品牌域、
/// 多次重试均为 0 条，页面提示 VIP），与 `view_video_hd.php` 是同一道
/// 会员墙，保留只会给出一个永远为空的分类。
enum Porn91Category {
  hot('热门', 'hot'),
  topThisWeek('本周排行', 'top'),
  topLastWeek('上周排行', 'top', extraQuery: {'m': '-1'}),
  featured('精华', 'rf'),
  tenMinutes('10 分钟以上', 'long'),
  twentyMinutes('20 分钟以上', 'longer'),
  favorite('收藏最多', 'tf'),
  discussed('讨论最多', 'md'),
  mostFavorited('最受欢迎', 'mf'),
  original('原创', 'ori');

  const Porn91Category(this.label, this.code, {this.extraQuery = const {}});

  final String label;

  /// `v.php?category=` 的取值。
  ///
  /// 站点存在 `category=top&m=-1`（上周排行）这种“额外参数”形态，
  /// 不能把 `top&m=-1` 当作单个查询值传（会被百分号编码成字面量）。
  final String code;

  final Map<String, String> extraQuery;
}

/// 91porn 详情页解析出的直链候选。
///
/// [mediaId] 是链接里的媒体编号；站点在“会话未预热”时会把整页换成另一个
/// 视频（海报与播放源换成同一个无关编号），因此它只用于识别“拿到的是哪个
/// 视频”，真正的前置条件是先预热会话。
@immutable
final class Porn91StreamCandidate {
  const Porn91StreamCandidate({required this.streamUrl, required this.mediaId});

  final String streamUrl;
  final String mediaId;
}
