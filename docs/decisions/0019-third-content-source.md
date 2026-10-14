# ADR-0019：第三个内容源（91porn）与能力位接入方式

- 状态：已接受
- 日期：2026-10-14

## 背景

应用此前只有两个内容源：Rule34Video（R34V）与 Hanime。两者不是通过插件机制接入的，
而是「`ContentSite` 枚举 + 每站一对 api/parser + `Rule34VideoApi` 作为门面做
`if (site == …)` 分发」。要加入第三个源 91porn，必须先决定接入面，否则每加一个源
都会把站点判断散落到 UI 各处。

91porn 与前两个源的结构差异较大：

- 没有账号体系（无登录、收藏、播放列表、评论、订阅接口）；
- 没有统一的“最新/热门/高评分”信息流，只有各自独立的分类导航；
- 播放页把真实 MP4 直链写在 `document.write(strencode2("…"))` 里，容器里另有一条
  全站固定的广告诱饵源；
- 有两条会“静默返回错误内容”的行为：会话未预热时详情页会返回另一个视频；
  直链带约 15 分钟过期的 token。

## 决策

### 1. 用 `ContentSiteCapabilities` 表达“这个源不支持什么”

新增 `ContentSite.porn91`，能力位**全部保持 false**。现有 UI 已在约 20 处按
`site.capabilities.*` 决定是否渲染动作（`video_card.dart`、`video_detail_page.dart`、
`search_page.dart`、`home_page.dart`），因此不需要为“隐藏不支持的功能”改任何界面，
只需要在确实存在站点特判的地方补分支。

这比“再加一个 `if (site != porn91)`”更稳：能力位是声明式的，新增源时默认什么都不开，
遗漏表现为“少了个入口”，而不是“点了报错”。

### 2. 不新增数据库表、不做 schema 迁移

视频标识早已是 `<siteId>:<id>` 前缀方案（`VideoItem.contentKey` /
`legacyCompatibleStorageId`），播放进度、下载记录、本地分类库三处都直接复用，
天然支持任意多个源。因此第三个源不需要迁移。

### 3. 复用现有扩展点，而不是新建分发层

- 详情获取：门面的 `_fetchVideoDetails` 加一个 `porn91` 分支；
- 列表/搜索：`loadFeedForSite` / `searchVideosForSite` 委托；
- 媒体请求头：`mediaHeadersFor` 委托 `Porn91Api.mediaHeaders()`；
- 播放直链过期：直接复用既有的 `refreshVideoDetails`（门面已按站点缓存失效）。

**推论（重要）**：既然复用门面的通用缓存与强制刷新，`Porn91Api` 自己就**不能**再缓存详情，
否则 `refreshVideoDetails` 无法穿透，过期直链会反复失败。

### 4. 反抓取行为在客户端内处理，不暴露给 UI

- 会话预热：`Porn91Api` 在取详情前先请求一次 `/v.php?category=rf`；
  实测只有 `v.php` 列表页会预热会话，请求首页无效。
- 诱饵过滤：解析器只认 `strencode2` 编码块，并显式丢弃文件名 `358999.mp4` 的源。

这两条都写在 `docs/porn91_api_endpoints.md` 并有巡检脚本断言。

### 5. 媒体库不为该源新增范围页签

媒体库的站点范围全部由账号数据支撑（收藏/稍后观看/历史）。91porn 没有账号，
新增页签只会永远是空的。它的下载与播放进度已经通过设备级的「本机」范围出现。

## 结果

- 新增 1 个源只需改：`content_source.dart`、`video_models.dart` 的 `detailPath`、
  门面 5 处委托、`Porn91Api` + `Porn91Parser`、几处枚举与设置标签、一个首页页面；
- 不新增数据库迁移、不删除任何既有 UI；
- UI 侧的“不支持”由能力位统一表达，后续新增源可照此办理；
- 站点特异性（预热、诱饵）集中在客户端与解析器一处，并有在线巡检脚本守住。

## 未决

- 门面 `Rule34VideoApi` 这个名字已名不副实（它现在是三站门面）。改名是独立的重构，
  涉及面广，本决策不做，避免与功能改动混在一个变更里。
- `VideoDetails` 带有 hanime 前缀的字段（`hanimeLiked` 等）说明共享模型已有站点特化泄漏；
  若将来第四、第五个源出现，应把这些字段收敛为按站点分组的对象。
