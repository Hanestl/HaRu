# 91porn 接口与解析手册

- 状态：已核实（2026-10，实测）
- 适用站点：`https://91porn.com`（与 `www.91porn.com`、`w0200`–`w0209.9p47q.com` 同一后端）
- 对应代码：`lib/core/api/porn91_api.dart`、`lib/core/api/porn91_parser.dart`
- 巡检脚本：`python tool/audit_porn91_endpoints.py`

本文记录客户端依赖的**可观测契约**。站点没有公开 API，全部结论来自真实抓取；
站点改版时先跑巡检脚本，再按本文对照更新解析器。

## 1. 域名

| 域名 | 能否直接列取内容 | 说明 |
| --- | --- | --- |
| `91porn.com` / `www.91porn.com` | 能 | **客户端使用的 base** |
| `w0200`–`w0209.9p47q.com` | 能 | 同一后端的品牌域，偶尔返回 436 限流页（重试即 200） |
| 裸域 `9p47q.com` | **不能**（实测返回 0 条目） | 因此不作为 base |

`ContentSite.porn91.baseUrl = 'https://91porn.com'`。

## 2. 接口

| 用途 | 请求 | 关键点 |
| --- | --- | --- |
| 分类列表 | `GET /v.php?category=<code>&viewtype=basic[&page=N]` | 每页 24 条；`page` 只在 >1 时传 |
| 搜索 | `GET /search_result.php?search_id=<关键词>&viewtype=basic[&page=N]` | **只用 `search_id`**；`search_key` 实测返回 0 条 |
| 详情 | `GET /view_video.php?viewkey=<key>&viewtype=basic` | 先预热会话，见 §4 |

### 分类 code（与 `Porn91Category` 一致）

| code | 导航文案（站点英文） | App 标签 |
| --- | --- | --- |
| `hot` | Hot | 热门 |
| `top` | Top this Mon. | 本周排行 |
| `top&m=-1` | Top last Mon. | 上周排行 |
| `rf` | Featured | 精华 |
| `long` | 10 mins | 10 分钟以上 |
| `longer` | 20 mins | 20 分钟以上 |
| `tf` | Favor | 收藏最多 |
| `md` | Discussed | 讨论最多 |
| `mf` | Most F. | 最受欢迎 |
| `ori` | 91 | 原创 |

**`category=hd` 不采用**：实测恒为空列表（两个品牌域、多次重试均 0 条，页面提示 VIP），
与 `view_video_hd.php` 是同一道会员墙。

`top&m=-1` 是站点的“额外参数”形态，必须作为独立查询参数发送；
把 `top&m=-1` 当作单个 `category` 值传入会被百分号编码成字面量，实测再次返回 0 条。

## 3. 页面结构

### 列表页卡片

```html
<div class="well well-sm videos-text-align">
  <a href="https://…/view_video.php?viewkey=<VIEWKEY>&page=1&c=<TOKEN>&viewtype=basic&category=…">
    <div class="thumb-overlay" id="playvthumb_<ID>">
      <img class="img-responsive" src="https://1729130453.rsc.cdn77.org/thumb/<ID>.jpg" />
      <div class="hd-text-icon">HD</div>
      <span class="duration">00:22:15</span>
    </div>
    <span class="video-title title-truncate m-t-5">…</span>
  </a>
</div>
```

- 视频标识是 `viewkey`（数字或 md5 形态），**只能用 `viewkey` 回到详情页**；
  `playvthumb_<ID>` 与 `/thumb/<ID>.jpg` 不总相同，不能互推，也不能当作视频标识。
- 卡片没有稳定的“按视频”锚点，解析时以 `a[href*="view_video.php"]` 为准，并按 `viewkey` 去重。
- `.hd-text-icon` 徽章不可信（免费主源本身可能是 720p），客户端不展示该徽章。

### 详情页播放器

```html
<div class="video-container">
  <video id="player_one" poster="https://1729130453.rsc.cdn77.org/thumb/<ID>.jpg">
    <!-- 注释掉的诱饵源，全站固定 -->
    <!-- <source src="https://ccm.91p52.com/358999.mp4?st=…" type='video/mp4'> -->
    <script>
      document.write(strencode2("%3c%73%6f%75%72%63%65%20…"))
    </script>
  </video>
</div>
```

真实播放源＝把 `strencode2("…")` 的参数 percent-decode 后得到的 `<source src='…'>`：

```
https://la.btc620.com//mp43/<ID>.mp4?st=<校验串>&e=<unix秒>&f=<校验串>
```

### 解析规则

1. 只认 `strencode2` 编码块；页面里的裸 `<source>` 属于注释掉的诱饵，**整条丢弃**。
2. 丢弃文件名等于 `358999.mp4` 的源。该文件全站固定、体积常常比真片更大，
   **绝不能按体积取最大**（历史故障正是这样选错的）。
3. `http://` 源规范化为 `https://`。
4. 标题取 `<title>` 去掉 ` - 91porn` 尾巴；标题若等于站名（错误页/通用页）则视为无效。
5. 海报编号 `<poster>` 里的 `/thumb/<ID>.` 用于识别“这一页是谁”。

## 4. 两条反抓取行为（必须处理）

### 4.1 会话未预热时详情页会返回另一个视频

**实测**：新建 cookie 会话后**第一次**请求详情页，站点返回的是**另一个视频的详情页**——
HTTP 200，海报与播放源**一起**被替换成同一个无关编号，页面完全自洽。
因此无法在事后识别，只能在请求前预热。

| 实测路径 | 结果 |
| --- | --- |
| 冷会话 → `GET /` → 详情页 | 仍返回错误视频（预热无效） |
| 冷会话 → 详情页 | 返回错误视频（例如 `868208`，期望 `1245148`） |
| 冷会话 → `GET /v.php?category=…` → 详情页 | 返回正确视频 |
| 冷会话 → 另一个详情页 → 目标详情页 | 返回正确视频 |

**结论**：任何 `v.php` 列表页请求都会预热会话。客户端在取详情前先请求一次
`/v.php?category=rf`（`Porn91Api._warmSession`），并且列表浏览天然已经预热过。

### 4.2 直链带短时效 token

`e=<unix 秒>` 是过期时间（实测约 15 分钟），`st`/`f` 是校验串。

- 直链**不可长期缓存**，每次播放/下载前都要重新抓详情页；
- 客户端依赖 `refreshVideoDetails`（门面已按站点做缓存失效），
  因此 91porn 客户端**不能**再自带一层详情缓存，否则强制刷新会失效。

## 5. 媒体响应

| 项 | 值 |
| --- | --- |
| `Content-Type` | `application/octet-stream`（不是 `video/mp4`，但文件是正常 MP4） |
| `Content-Length` | 有（实测 28.8MB / 104MB） |
| `Accept-Ranges` | `bytes`（可续传、可并行分片） |
| `Referer` | 带不带都能取到 |
| 缩略图 | `1729130453.rsc.cdn77.org/thumb/<ID>.jpg`，**不校验 Referer** |

## 6. 已知边界

- 高清是会员墙：`view_video_hd.php` 对非会员只返回一句提示，页内无直链；
  `category=hd` 同样恒为空。**无免费路径可逆**，客户端不提供高清选项。
- 免费主源分辨率随机（实测同一站点出现 202x360 / 404x720 / 202x244），
  因此客户端的清晰度标签只写“默认”，不声称具体分辨率。
- 站点末页之后不返回空列表而是循环内容，分页终止由重复条目判定。
- 没有账号级能力：无收藏/播放列表/评论/订阅接口，`ContentSiteCapabilities` 全为 false。
