# Hanime1 (Hanime) 全量接口清单与巡检维护手册

> 本手册整理了 HaRu 项目中所依赖的 Hanime1 (`https://hanime1.me`) 站点全部交互端点、请求规范、DOM/JSON 解析特征以及定期健康探测方案。

---

## 一、架构概览与关键反爬/安全特征

| 特征项 | 规范与注意事项 |
| :--- | :--- |
| **基础域名** | `https://hanime1.me` |
| **User-Agent 与网络栈** | 模拟现代 Android 浏览器 UA：`Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36`。<br>Android 平台基于 `package:native_dio_adapter` 优先启用 Cronet 原生网络引擎（HTTP/2），仅在宿主环境缺失所有 Cronet Provider（如无 Google Play 服务或自定义 Cronet 库）导致引擎初始化不可用时，才平滑降级至 `IOHttpClientAdapter`；请求运行期间的业务网络异常（TLS 握手、超时、连接重置或 4xx/5xx）不会切换适配器。 |
| **Cloudflare 防护机制** | 站点受 Cloudflare CDN / 5秒盾 / Turnstile 保护。当 HTTP 状态返回 403 或页面内容包含 `just a moment`、`cloudflare`、`attention required`、`checking your browser`、`verify you are human`、`cf-turnstile-response` 时触发拦截判定。<br>HaRu 客户端实现了 `HanimeCloudflareCoordinator`，在被拦截时自动调起前台/无头 WebView 完成人机验证，随后提取 `cf_clearance` 会话 Cookie 并回填至 `CookieJar` 重新发起请求。 |
| **Laravel CSRF 机制** | 站点基于 Laravel 框架开发。所有写操作与敏感请求（登录、点赞、稍后观看、播放列表增删改、订阅、评论、资料更新等）均强制校验 CSRF。<br>1. **提取位置**：优先从 `<meta name="csrf-token">` 的 `content` 属性提取，兜底从 `<input name="_token">` 的 `value` 提取。<br>2. **提交规范**：请求体中携带 `_token: <token>`，同时 HTTP 请求头携带 `X-CSRF-TOKEN: <token>`。 |
| **RESTful 伪动词规范** | 站点修改或删除资源时，采用标准表单 POST 搭配 `_method` 字段模拟动词：<br>- 播放列表编辑与删除：`_method: PUT`<br>- 账号资料、密码、头像修改：`_method: patch`<br>- 历史记录删除：直接调用 `DELETE /user/tab-item/{videoId}`。 |
| **播放源内嵌机制** | 站点未公开独立的流媒体 JSON 接口，视频直链直接内嵌于详情页 HTML 中：<br>依次检索 `<video source>`、`<video[src]>`、`[data-url]`、`a[href*=".mp4"]`，解析出各个清晰度（1080p、720p、480p）的 MP4 直链与备用流。 |
| **评论 JSON+HTML 混合机制** | 评论与回复接口（`/loadComment`、`/loadReplies`）响应为标准 JSON 格式，但载荷主体为局部 HTML 片段（`{"comments": "..."}` 或 `{"replies": "..."}`），客户端需对其进行二次 DOM 解析。 |

---

## 二、全量接口清单 (8 个模块 / 22 个端点)

### 1. 首页流媒体与分区 (Home Feeds & Sections)

| 功能 | 请求方式与路径 | 关键参数 | 关键解析目标 / 选择器 | 健康探测判定 |
| :--- | :--- | :--- | :--- | :--- |
| **首页分区流** | `GET /` | 无 | `.home-rows-videos-wrapper` 容器、前置 `h3` 标题、`a[href*="watch?v="]` 视频卡片 | HTTP 200，HTML 包含分区标题与视频卡片 |
| **首页分页流** | `GET /` | `page={page}` | 同上，视频列表 `a[href*="watch?v="]` | HTTP 200，成功返回指定页码视频卡片 |

### 2. 高级搜索与多维筛选 (Search & Filters)

| 功能 | 请求方式与路径 | 关键参数 | 关键解析目标 / 选择器 | 巡检注意事项 |
| :--- | :--- | :--- | :--- | :--- |
| **综合搜索与多维筛选** | `GET /search` | `query={keyword}`<br>`page={page}`<br>`genre={genre}`<br>`sort={sort}`<br>`date={year_month}`<br>`duration={duration}`<br>`tags[]={tag}`<br>`brands[]={brand}`<br>`broad=on` | 结果容器中的 `a[href*="watch?v="]`、标题 `.home-rows-videos-title` / `.video-title`、封面 `img[data-src]`、作者与发布时间 | `tags[]` 与 `brands[]` 必须以重复键数组格式传递（如 `tags[]=A&tags[]=B`）；`genre` 与全局导航栏分类隔离。 |

### 3. 视频详情与播放源 (Video Details & Playback)

| 功能 | 请求方式与路径 | 关键参数 | 关键解析目标 / 选择器 | 健康探测判定 |
| :--- | :--- | :--- | :--- | :--- |
| **视频详情与播放源** | `GET /watch` | `v={videoId}` | 1. **播放直链**：`<video source>`、`video[src]`、`[data-url]`、`a[href*=".mp4"]`；<br>2. **元数据**：标题 `#shareBtn-title` / `h1`、观看次数、发布日期；<br>3. **交互状态**：`like-status`、`unlike-status`、`subscribe-status`、`#playlist-save-checkbox`；<br>4. **关联推荐**：剧集系列 `#video-playlist-wrapper` 与关联推荐 `#related-tabcontent`。 | HTTP 200，HTML 包含视频标题且至少能提取到一个有效 MP4 直链。 |

### 4. 视频评论系统 (Comments)

| 功能 | 请求规范 | 参数与载荷 | 响应与解析判定 |
| :--- | :--- | :--- | :--- |
| **获取主评论** | `GET /loadComment` | `type=video&id={videoId}` | 公开接口。返回 JSON `{"comments": "<HTML片段>"}`。解析评论者昵称、头像、内容、时间、点赞数、回复数、举报属性。 |
| **获取子回复** | `GET /loadReplies` | `id={commentId}` | 公开接口。返回 JSON `{"replies": "<HTML片段>"}`。解析回复列表容器 `[id^="reply-start-"]`。 |
| **发表主评论** | `POST /createComment` | Header: `X-CSRF-TOKEN: {token}`<br>Body: `_token={token}&comment-user-id={userId}&comment-type=video&comment-foreign-id={videoId}&comment-text={text}&comment-count=1&comment-is-political=0` | 需登录。评论发布成功后返回更新结果。 |
| **回复指定评论** | `POST /replyComment` | Header: `X-CSRF-TOKEN: {token}`<br>Body: `_token={token}&reply-comment-id={commentId}&reply-comment-text={text}` | 需登录。令牌从当前视频详情页提取。 |
| **评论赞 / 踩** | `POST /commentLike` | Header: `X-CSRF-TOKEN: {token}`<br>Body: `_token={token}&foreign_type=comment&foreign_id={commentId}&is_positive={1\|0}&comment-like-user-id={userId}&comment-likes-count={count}&comment-likes-sum={sum}&like-comment-status={0\|1}&unlike-comment-status={0\|1}` | 需登录。即时切换点赞/踩状态。 |
| **举报不良评论** | `POST /user/{userId}/report` | Header: `X-CSRF-TOKEN: {token}`<br>Body: `_token={token}&redirect-url=/watch?v={videoId}&reportable-id={commentId}&reportable-type=comment&reason={reason}` | 需登录。提交投诉举报原因。 |

### 5. 媒体库收藏与互动 (Library & Reactions)

| 功能 | 请求规范 | 参数与载荷 | 业务说明 |
| :--- | :--- | :--- | :--- |
| **点赞视频列表** | `GET /user/{userId}/likes` | `page={page}` | 需登录。解析当前账号已点赞的视频流。 |
| **稍后观看列表** | `GET /user/{userId}/saves` | `page={page}` | 需登录。解析当前账号稍后观看清单中的视频流。 |
| **视频点赞 / 点踩** | `POST /like` | Header: `X-CSRF-TOKEN: {token}`<br>Body: `_token={token}&like-foreign-id={videoId}&like-is-positive={1\|0}&like-status={1\|''}&unlike-status={1\|''}&likes-count={likes}&unlikes-count={unlikes}&like-user-id={userId}` | 需登录。`like-status` 为空串表示添加点赞，为 `1` 表示取消点赞。 |
| **稍后观看开关** | `POST /save` | Header: `X-CSRF-TOKEN: {token}`<br>Body: `_token={token}&input_id=save&video_id={videoId}&is_checked={true\|false}&user_id=` | 需登录。`input_id=save` 是 Hanime 官方内建的“稍后观看”固定标识。 |

### 6. 在线观看历史 (Watch History)

| 功能 | 请求规范 | 参数与载荷 | 业务说明 |
| :--- | :--- | :--- | :--- |
| **在线历史列表** | `GET /user/{userId}/histories` | `sort={latest\|views\|...}&page={page}` | 需登录。按时间或热度分页拉取用户在线播放记录。 |
| **删除单条历史** | `DELETE /user/tab-item/{videoId}` | Header: `X-CSRF-TOKEN: {token}`<br>Body: `tab=histories` | 需登录。从服务端彻底移除指定视频的播放历史记录。 |

### 7. 播放列表 (Playlists)

| 功能 | 请求规范 | 参数与载荷 | 业务说明 |
| :--- | :--- | :--- | :--- |
| **我的播放列表** | `GET /user/{userId}/playlists` | `page={page}` | 需登录。解析 `.user-tab-item-wrapper` 提取各播单标题、封面、视频数及 `listCode`。 |
| **播放列表内容** | `GET /playlist` | `list={listCode}&page={page}` | 公开接口。无需登录即可查看指定播放列表的视频内容。 |
| **创建播放列表** | `POST /createPlaylist` | Header: `X-CSRF-TOKEN: {token}`<br>Body: `_token={token}&create-playlist-video-id={videoId}&playlist-title={title}&playlist-description={desc}` | 需登录。创建播单并将当前视频作为初始内容加入。 |
| **修改播单资料** | `POST /playlist/{listCode}` | Header: `X-CSRF-TOKEN: {token}`<br>Body: `_token={token}&_method=PUT&playlist-title={title}&playlist-description={desc}` | 需登录。通过 `_method=PUT` 伪动词更新播单标题与简介。 |
| **删除播放列表** | `POST /playlist/{listCode}` | Header: `X-CSRF-TOKEN: {token}`<br>Body: `_token={token}&_method=PUT&playlist-delete=on` | 需登录。通过携带 `playlist-delete: on` 删除整个播单。 |
| **视频加入/移出播单** | `POST /save` | Header: `X-CSRF-TOKEN: {token}`<br>Body: `_token={token}&input_id={listCode}&video_id={videoId}&is_checked={true\|false}&user_id=` | 需登录。复用 `/save` 端点，将 `input_id` 指定为播放列表 `listCode` 即可。 |
| **移出播单指定视频** | `POST /deletePlayitem` | Header: `X-CSRF-TOKEN: {token}`<br>Body: `_token={token}&playlist_id={listCode}&video_id={videoId}&count={count}` | 需登录。在播单详情页内删除指定视频条目。 |

### 8. 作者订阅与账号管理 (Subscriptions & Account)

| 功能 | 请求规范 | 参数与载荷 | 业务说明 |
| :--- | :--- | :--- | :--- |
| **我的订阅更新流** | `GET /subscriptions` | `page={page}` | 需登录。解析 `.subscriptions-nav`（作者头像与名称）与 `.content-padding-new`（作者最新作品流）。 |
| **关注 / 取关作者** | `POST /subscribe` | Header: `X-CSRF-TOKEN: {token}`<br>Body: `_token={token}&subscribe-user-id={userId}&subscribe-artist-id={artistId}&subscribe-status={1\|''}` | 需登录。`artistId` 从视频详情页的 `input[name="subscribe-artist-id"]` 提取。 |
| **账号登录获取令牌** | `GET /login` | 无 | 获取登录页面，提取 `<meta name="csrf-token">`。 |
| **提交账号登录** | `POST /login` | Header: `X-CSRF-TOKEN: {token}`<br>Header: `Referer: https://hanime1.me/login`<br>Body: `_token={token}&email={email}&password={password}` | 需禁用重定向跟随以捕获 Set-Cookie 响应头。登录成功后重定向至首页，首页 `#user-modal-trigger` 即包含用户 ID。 |
| **账号退出登录** | `GET /logout` | 无 | 清除服务端会话 Cookie。 |
| **公开用户主页** | `GET /user/{userId}` | 无 | 公开接口。解析文本匹配 `X 位订阅者 • Y 个视频` 统计数据。 |
| **账号编辑数据** | `GET /user/{userId}/edit` | 无 | 需登录。获取当前用户名、邮箱及更新表单令牌。 |
| **更新个人资料** | `POST /user/{userId}` | Body: `_token={token}&_method=patch&type=profile&name={name}&email={email}` | 需登录。通过 `_method=patch` 更新用户名与邮箱。 |
| **更新账号密码** | `POST /user/{userId}` | Body: `_token={token}&_method=patch&type=password&password_old={old}&password_new={new}&password_new_confirm={new}` | 需登录。更新密码。 |
| **更新账号头像** | `POST /user/{userId}` | Content-Type: `multipart/form-data`<br>Fields: `_token`, `_method: patch`, `type: photo`, `photo: <file>` | 需登录。上传图片文件更新用户头像。 |

---

## 三、定期巡检与自动化探测建议

### 1. 核心巡检项目矩阵

| 巡检维度 | 探测目标 | 告警触发阈值 | 建议巡检周期 |
| :--- | :--- | :--- | :--- |
| **连通性与 CF 挑战** | `GET /` 带浏览器 UA | HTTP 状态非 200 或返回 Cloudflare Challenge / 5秒盾拦截页 | 每日 / 发布前 |
| **首页分区容器** | `GET /` | 无法提取 `.home-rows-videos-wrapper` 容器或视频条目为 0 | 每周 |
| **综合搜索可用性** | `GET /search?query=test` | 未返回包含 `a[href*="watch?v="]` 的卡片列表 | 每周 |
| **多维筛选兼容性** | `GET /search?genre=3DCG&sort=latest` | 响应非 200 或出现异常报错 | 每月 |
| **视频播放源有效性** | `GET /watch?v={videoId}` | 页面无法提取到任何有效的 MP4 视频直链 (`sources.isEmpty`) | 每周 |
| **评论异步接口** | `GET /loadComment?type=video&id={videoId}` | 返回非合规 JSON 或 JSON 中的 `comments` 片段为空 | 每月 |
| **公开播放列表** | `GET /playlist?list={listCode}` | 页面结构变更导致无法提取包含的视频条目 | 每月 |

### 2. 自动化巡检执行方式

在 Python 环境下直接执行包含全量接口探测的脚本：
```bash
python tool/audit_hanime1_endpoints.py
```
脚本将按顺序探测 Hanime 的关键公开端点并对响应特征进行断言：
- 当返回状态码 `200` 且满足 DOM / JSON 结构特征时判定为 `PASS`；
- 当遇到 Cloudflare 挑战拦截时将精确提示 `BLOCKED (Cloudflare)`；
- 当返回内容发生结构变动时输出 `FAIL` 并告警。
