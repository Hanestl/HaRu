# Rule34Video (R34V) 全量接口清单与巡检维护手册

> 本手册整理了 HaRu 项目中所依赖的 Rule34Video 站点全部交互端点、请求规范、DOM/JSON 解析特征以及定期健康探测方案。

---

## 一、架构概览与关键反爬/安全特征

| 特征项 | 规范与注意事项 |
| :--- | :--- |
| **基础域名** | `https://rule34video.com` |
| **User-Agent 策略** | 官网部署了 `Server: ddos-guard` 防护。简单/默认爬虫 UA（如 Python-urllib/Requests 无头请求）会被直接拦截返回 403 Forbidden。必须使用客户端自定义合规 UA（如 `HaRu Android/2.0.1`）或标准现代浏览器 UA。 |
| **KVS 异步区块机制** | 官网大量采用 Kernel Video Sharing (KVS) 异步加载协议：`?mode=async&function=get_block&block_id=...`。响应内容为局部 HTML 片段（非完整页面），需针对片段结构单独做 DOM 提取。 |
| **CSRF / 安全令牌机制** | - 普通视频收藏/点赞/订阅：通常通过附带 `mode=async` 并带上会话 Cookie 请求。<br>- 播放列表写操作（增删改）：必须先请求 `/playlist_security.php` 动态换取 64 位十六进制 `csrf_token`，并在随后的写请求中携带请求头 `X-Playlist-CSRF: <token>`。 |
| **播放打点与历史同步** | 视频播放时必须向 `/player/stats.php` 发送带 `Referer` 的打点请求（`event=VideoPlay,`），服务端收到后才会将该视频记入当前账号的历史记录（`/my/history/`）。 |
| **封面懒加载机制 (redesign: 1)** | 页面中仅前 5 个卡片加载真实 `src`，第 6 个起使用 1x1 base64 GIF 占位符，真实封面存放在 `data-rd-src`、`data-rd-jpg` 或 `data-rd-webp` 中。 |

---

## 二、全量接口清单 (12 个模块 / 31 个端点)

### 1. 首页流媒体 (Home Feeds)

| 功能 | 请求方式与路径 | 关键参数 | 关键解析目标 / 选择器 | 健康探测判定 |
| :--- | :--- | :--- | :--- | :--- |
| **最新视频 (第1页)** | `GET /latest-updates/` | 无 | `div.item`, `a.th`, `img` 属性 | HTTP 200，HTML 包含 `item` 卡片及缩略图 |
| **最新视频 (第2+页)** | `GET /latest-updates/{page}/` | 无 | 同上 | HTTP 200 |
| **热门视频 (第1页)** | `GET /most-popular/` | 无 | 同上 | HTTP 200 |
| **热门视频 (第2+页)** | `GET /most-popular/{page}/` | 无 | 同上 | HTTP 200 |
| **最高评分 (第1页)** | `GET /top-rated/` | 无 | 同上 | HTTP 200 |
| **最高评分 (第2+页)** | `GET /top-rated/{page}/` | 无 | 同上 | HTTP 200 |
| **关注更新流 (需登录)** | `GET /my/subscriptions/` | `mode=async`<br>`function=get_block`<br>`block_id=list_videos_videos_from_my_subscriptions`<br>`sort_by=`<br>`from={page}` | 同上（KVS 局部 HTML） | 需登录。返回关注创作者的最新视频流。 |
| **首页与会话状态探针** | `GET /` | 无 | 解析当前登录用户 ID (`SiteParser.userId`) | HTTP 200。客户端用于 `restoreSession()` 验证会话存活。 |

### 2. 搜索与筛选 (Search & Filters)

| 功能 | 请求方式与路径 | 关键参数 | 关键解析目标 / 选择器 | 巡检注意事项 |
| :--- | :--- | :--- | :--- | :--- |
| **视频搜索 (第1页)** | `GET /search/{query}/` | 可选过滤参数：<br>`sort_by`、`post_date_from`、`duration_from`、`tag_ids` 等 | `div.item`、标题 `.title`、时长 `.duration` | 关键词需经 URL 编码 |
| **视频搜索 (第2+页异步)** | `GET /search/` | `mode=async`<br>`function=get_block`<br>`block_id=custom_list_videos_videos_list_search`<br>`q={query}`<br>**`from_videos={page}`** | 同上（KVS 局部 HTML） | **注意**：分页参数必须为 `from_videos`，官网已废弃 `from_videos+from_albums`。 |

### 3. 搜索联想与自动补全 (Suggestions JSON API)

| 功能 | 请求方式与路径 | 请求参数 | 响应格式 | 健康探测判定 |
| :--- | :--- | :--- | :--- | :--- |
| **标签补全** | `GET /tags_json.php` | `id=true&q={query}` | JSON 字典: `{"tag_id": "name", ...}` | 返回合法 JSON，Key 为数字 ID，Value 为标签名 |
| **分类补全** | `GET /categories_json.php` | `id=true&q={query}` | JSON 字典: `{"cat_id": "name", ...}` | 同上 |
| **Model 补全** | `GET /models_json.php` | `q={query}` | JSON 数组: `[{"title": "..."}, ...]` | 返回合法 JSON 数组 |

### 4. 发现目录 (Discovery Directories)

| 功能 | 请求方式与路径 | 翻页协议 | 关键解析目标 / 选择器 |
| :--- | :--- | :--- | :--- |
| **分类目录** | `GET /categories/` | 第2+页：`/categories/{page}/` | `div.item` / `.thumb`，提取分类封面与总数 |
| **标签目录** | `GET /tags/` | 第2+页异步：`?mode=async&function=get_block&block_id=list_tags_tags_list&section=All&sort_by=tag&from={page}` | 标签列表与视频数 |
| **Model 目录** | `GET /models/` | 第2+页：`/models/{page}/` | `div.item`，提取 Model 头像、名称及视频数 |
| **频道目录** | `GET /channels/` | 仅首屏单页 | 频道卡片与介绍 |
| **反查/补全实体详情** | `GET /{categories\|models}/?q={title}` | 目录内搜索 | 反查过滤分类/模型的精确 `filterId` 及头像 |

### 5. 发现实体与频道关联视频流

| 功能 | 路径规范 | 翻页规则 |
| :--- | :--- | :--- |
| **分类视频** | `/categories/{slug}/` | 支持常规路径 `/categories/{slug}/{page}/` 或异步区块 `custom_list_videos_common_videos` (`from={page}`) |
| **标签视频** | `/tags/{tag_id}/` | 路径翻页：`/tags/{tag_id}/{page}/` |
| **Model 视频** | `/models/{slug}/` | 支持路径 `/models/{slug}/{page}/` 或异步区块 `custom_list_videos_common_videos` |
| **上传者视频** | `/members/{userId}/videos/` | 第2+页异步：`?mode=async&function=get_block&block_id=list_videos_uploaded_videos&from_videos={page}` |

### 6. 视频详情与播放源 (Video Details & Playback)

| 功能 | 请求方式与路径 | 核心解析内容与提取规则 |
| :--- | :--- | :--- |
| **视频详情与播放** | `GET /video/{id}/{slug}/` | 1. **播放源**：从页内的 `flashvars` 对象提取 `video_url`（高/标清 MP4）和 `video_alt_url`（备用流）。<br>2. **元数据**：标题 `#main > h1`、上传者 `.user` / `a[href*="/members/"]`、点赞数 `.btn-like .count`。<br>3. **实体标签**：提取标签、分类、Model 的 URL 与 ID 关联。 |

### 7. 播放历史与打点上报 (Watch History & Stats)

| 功能 | 请求规范 | 参数与载荷 | 业务说明 |
| :--- | :--- | :--- | :--- |
| **播放打点上报** | `GET /player/stats.php` | `embed=0&video_id={id}&event=VideoPlay,&rnd={timestamp}`<br>Header: `Referer: {video.detailPath}` | 播放器打点，触发服务端将视频写入个人观看历史。 |
| **我的观看历史** | `GET /my/history/` | 第2+页：`/my/history/{page}/` | 需登录。分页拉取当前登录账号的观看历史。 |

### 8. 用户评论 (Comments)

| 功能 | 请求规范 | 参数与载荷 | 解析/结果判定 |
| :--- | :--- | :--- | :--- |
| **获取评论** | `GET /video/{id}/{slug}/` | 无（与视频详情同页服务端渲染） | 解析 `div.comm_item`、评论者头像、昵称、内容、发布时间 |
| **发表评论** | `POST /video/{id}/{slug}/?mode=async` | Header: `X-Requested-With: XMLHttpRequest`<br>Body: `action=add_comment&video_id={id}&comment={text}` | 需登录。站点返回审核提示 HTML/文本 |

### 9. 收藏夹 (Favorites)

| 功能 | 请求规范 | 参数与载荷 |
| :--- | :--- | :--- |
| **添加收藏** | `POST /video/{id}/{slug}/?mode=async` | Header: `X-Requested-With: XMLHttpRequest`<br>Body: `action=add_to_favourites&video_id={id}&fav_type=0&playlist_id=0` |
| **移出收藏** | `POST /video/{id}/{slug}/?mode=async` | Header: `X-Requested-With: XMLHttpRequest`<br>Body: `action=delete_from_favourites&video_id={id}&fav_type=0&playlist_id=0` |
| **我的收藏列表** | `GET /my/favourites/videos/` | 第2+页：`/my/favourites/videos/{page}/`<br>需登录。解析当前账号收藏视频。 |
| **公开收藏列表** | `GET /members/{userId}/favourites/videos/` | 第2+页：`/members/{userId}/favourites/videos/{page}/`<br>解析选择器：适配新版 `div.item.ma-v`, `a.ma-thumb`, `.ma-v__t` |

### 10. 播放列表 (Playlists)

| 功能 | 请求规范 | 载荷与安全令牌 |
| :--- | :--- | :--- |
| **我的播放列表** | `GET /my/playlists/` | 第2+页异步：`?mode=async&function=get_block&block_id=list_playlists_my_created_playlists&sort_by=last_content_date&from_my_playlists={page}` |
| **获取 CSRF 令牌** | `GET /playlist_security.php?_={timestamp}` | Header: `Origin: https://rule34video.com`<br>返回 JSON: `{"csrf_token": "..."}` |
| **创建播放列表** | `POST /create-playlist/` | Body: `title={title}&description={desc}&is_private=0\|1&action=add_new_complete` |
| **编辑播放列表** | `POST /edit-playlist/{playlistId}/` | Body: `title={title}&description={desc}&is_private=0\|1&action=change_complete` |
| **删除播放列表** | `POST /my/playlists/` | Header: `X-Playlist-CSRF: {token}`<br>Body: `action=delete_playlists&delete[]={playlistId}&mode=async&format=json` |
| **视频加入列表** | `POST /video/{id}/{slug}/` | Header: `X-Playlist-CSRF: {token}`<br>Body: `action=add_to_favourites&video_id={id}&fav_type=10&playlist_id={playlistId}&mode=async&format=json` |
| **视频移出列表** | `POST /video/{id}/{slug}/` | Header: `X-Playlist-CSRF: {token}`<br>Body: `action=delete_from_favourites&video_id={id}&fav_type=10&playlist_id={playlistId}&mode=async&format=json` |
| **查看列表内容** | `GET /playlists/{playlistId}/{slug}/` | 翻页：`?mode=async&function=get_block&block_id=playlist_view_playlist_view&from={page}` |

### 11. 关注与订阅 (Subscriptions)

| 功能 | 请求规范 | 载荷与参数 |
| :--- | :--- | :--- |
| **我的订阅作者列表** | `GET /my/subscriptions/?view=members` | 第2+页异步：`?mode=async&function=get_block&block_id=list_members_subscriptions_my_subscriptions&sort_by=added_date&from_my_subscriptions={page}&view=members` |
| **公开订阅列表** | `GET /members/{userId}/subscriptions/` | 翻页：`?mode=async&function=get_block&block_id=list_members_subscriptions_my_subscriptions&from_my_subscriptions={page}`<br>*（服务端已知端点，客户端当前未实现调用）* |
| **关注/取关上传者** | `POST /members/{uploaderId}/?mode=async` | Body: `action=subscribe\|unsubscribe&{subscribe\|unsubscribe}_user_id={uploaderId}` |
| **关注/取关分类或 Model** | `POST /video/{id}/{slug}/?mode=async` | Body: `action=subscribe\|unsubscribe&{subscribe\|unsubscribe}_{category\|model}_id={id}` |

### 12. 会员认证与个人中心 (Auth & Member Profile)

| 功能 | 请求规范 | 关键逻辑 / 校验点 |
| :--- | :--- | :--- |
| **用户登录** | `POST /login/` | Body: `username={email}&pass={password}&action=login&email_link=https://rule34video.com/email/`<br>响应通过 302 重定向并写入 Cookie；重定向后首页若包含用户 ID 则登录成功 |
| **用户登出** | `GET /logout/` | 服务端作废会话并清除 Cookie |
| **查看用户资料** | `GET /members/{userId}/` | 解析新版个人主页 `<section class="ma-hero">`、`#rdp-name`、订阅数 `b[data-rdp-subs-count]`、头像 `.ma-avatar img` |

---

## 三、定期巡检与自动化探测建议

### 1. 核心巡检项目矩阵

| 巡检维度 | 探测目标 | 告警触发阈值 | 建议巡检周期 |
| :--- | :--- | :--- | :--- |
| **反爬/连通性** | `GET /` 带客户端 UA | HTTP 状态非 200 或返回 DDOS-GUARD 拦截页 | 每日 / 发布前 |
| **最新视频流** | `GET /latest-updates/` | HTTP 状态非 200 或无法匹配视频卡片 | 每周 |
| **封面懒加载机制** | 首页视频列表第 6 个视频 | 未提取到 `data-rd-src` / `data-rd-jpg` 且 `imageUrl == null` | 每周 |
| **搜索异步分页** | `GET /search/` 带 `from_videos=2` | 返回 HTML 为空或出现全站 404 / 重定向至第 1 页 | 每周 |
| **播放打点服务** | `GET /player/stats.php` | 状态码返回非 200 | 每月 |
| **Member Area 容器** | `GET /members/2421071/` | 未能匹配 `ma-hero` 或未能匹配 `item ma-v` | 每月 / 社区有反馈时 |
| **播放源 Flashvars** | 随机视频详情页 | 正则无法匹配 `flashvars` 或 `video_url` 为空 | 每周 |
| **联想词 JSON 接口** | `/tags_json.php` 等 | 无法解析为 JSON 或格式变更 | 每月 |

### 2. 自动化巡检执行方式

在 Python 环境下直接执行包含全量接口探测的脚本：
```bash
python tool/audit_rule34video_endpoints.py
```
若全部端点输出状态码 `200` 且包含预期 DOM/JSON 特征，则代表全站接口运转健康。
