import 'dart:isolate';

/// 整页 HTML 解析下放 Isolate 的体积阈值（字符数）。
///
/// 站点列表页/详情页的 HTML 常在 100KB 以上，`html` 包同步解析会占用主 isolate
/// 十几到几十毫秒，滚动与转场因此掉帧；而小页面（AJAX 分块、错误页、表单响应）
/// 直接解析更快，因为 `Isolate.run` 自身有约 1ms 级启动与消息传递开销。
/// 该阈值与 `_parseComments`/`_parseVideoList`/`_parseVideoDetails` 等既有解析入口一致。
const int htmlIsolateThreshold = 10240;

/// 按体积决定是否把 [parse] 下放到后台 Isolate，避免大页面解析阻塞 UI 线程。
///
/// [parse] 只能捕获 [body] 与枚举、纯数据对象等可跨 Isolate 传递的值，
/// 不要捕获 repository、Provider 等不可发送对象。
Future<T> parseHtmlOffThread<T>(String body, T Function() parse) {
  if (body.length < htmlIsolateThreshold) {
    return Future.value(parse());
  }
  return Isolate.run(parse);
}
