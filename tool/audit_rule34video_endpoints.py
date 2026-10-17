#!/usr/bin/env python3
"""
Rule34Video (R34V) 全量接口健康探测与自动化巡检脚本

用途：
  对 HaRu 客户端中用到的所有 Rule34Video 接口进行自动化网络探测与结构特征断言。
  包含最新视频流、分页加载、会话探针、搜索分页、JSON 自动补全、发现目录、
  视频详情与播放源、播放打点、个人中心新版容器等全量链路。

运行方式：
  python tool/audit_rule34video_endpoints.py
"""

import sys
import urllib.request
import urllib.parse
import json
import time

# 兼容 Windows 控制台 UTF-8 输出
if sys.platform == "win32" and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

UA = 'HaRu Android/2.0.1'
BASE = 'https://rule34video.com'

def fetch(path, query=None, data=None, extra_headers=None, retries=2):
    url = BASE + path
    if query:
        url += '?' + urllib.parse.urlencode(query)
    headers = {'User-Agent': UA}
    if extra_headers:
        headers.update(extra_headers)
    req = urllib.request.Request(url, headers=headers)
    if data:
        req.data = urllib.parse.urlencode(data).encode('utf-8')
    for attempt in range(retries + 1):
        try:
            resp = urllib.request.urlopen(req, timeout=15)
            return resp.getcode(), resp.read().decode('utf-8', errors='replace'), resp.headers
        except urllib.error.HTTPError as e:
            if e.code >= 500 and attempt < retries:
                time.sleep(1.5)
                continue
            return e.code, e.read().decode('utf-8', errors='replace'), e.headers
        except Exception as e:
            if attempt == retries:
                return 0, str(e), {}
            time.sleep(1.5)

tests = [
    # 1. 首页流媒体 (客户端 FeedKind 真实路径)
    ("最新视频流 (第1页)", "/latest-updates/", None, None, lambda c, b: c == 200 and 'item' in b and 'data-rd-src' in b),
    ("最新视频流 (第2页分页)", "/latest-updates/2/", None, None, lambda c, b: c == 200 and 'item' in b),
    ("热门视频 (第1页)", "/most-popular/", None, None, lambda c, b: c == 200 and 'item' in b),
    ("最高评分 (第1页)", "/top-rated/", None, None, lambda c, b: c == 200 and 'item' in b),
    ("会话与首页探针 (restoreSession)", "/", None, None, lambda c, b: c == 200 and 'item' in b),

    # 2. 搜索与异步翻页
    ("搜索内容 (第1页)", "/search/overwatch/", None, None, lambda c, b: c == 200 and 'item' in b),
    ("搜索分页 (第2页异步 from_videos)", "/search/", {"mode": "async", "function": "get_block", "block_id": "custom_list_videos_videos_list_search", "q": "overwatch", "from_videos": "2"}, None, lambda c, b: c == 200 and 'item' in b),

    # 3. 自动补全建议 JSON
    ("标签建议 JSON", "/tags_json.php", {"id": "true", "q": "over"}, None, lambda c, b: c == 200 and b.startswith('{')),
    ("分类建议 JSON", "/categories_json.php", {"id": "true", "q": "3d"}, None, lambda c, b: c == 200 and b.startswith('{')),
    ("Model建议 JSON", "/models_json.php", {"q": "jack"}, None, lambda c, b: c == 200 and b.startswith('{') and 'items' in b),

    # 4. 发现目录
    ("分类列表", "/categories/", None, None, lambda c, b: c == 200 and 'item' in b),
    ("分类详情 (Virt-A-Mate)", "/categories/virt-a-mate/", None, None, lambda c, b: c == 200 and 'item' in b),
    ("标签列表", "/tags/", None, None, lambda c, b: c == 200 and 'tag' in b),
    ("标签详情 (/tags/25496/)", "/tags/25496/", None, None, lambda c, b: c == 200 and 'item' in b),
    ("Model列表", "/models/", None, None, lambda c, b: c == 200 and 'item' in b),
    ("Model详情 (/models/jackerman/)", "/models/jackerman/", None, None, lambda c, b: c == 200 and 'item' in b),
    ("频道列表", "/channels/", None, None, lambda c, b: c == 200 and 'item' in b),

    # 5. 视频详情与播放源
    ("视频详情 (/video/4666214/)", "/video/4666214/medusa6/", None, None, lambda c, b: c == 200 and 'flashvars' in b and 'video_url' in b),

    # 6. 播放历史与打点上报
    ("播放历史打点服务 (stats.php)", "/player/stats.php", {"embed": "0", "video_id": "4666214", "event": "VideoPlay,", "rnd": "1"}, {"Referer": "https://rule34video.com/video/4666214/medusa6/"}, lambda c, b: c == 200),

    # 7. 播放列表
    ("公开播放列表详情", "/playlists/2907071/test1104/", None, None, lambda c, b: c == 200 and ('item' in b or 'headline' in b)),

    # 8. 用户中心 Member Area (新版 ma- 结构)
    ("公开用户主页 (新版 ma-hero)", "/members/2421071/", None, None, lambda c, b: c == 200 and 'ma-hero' in b),
    ("公开用户收藏 (新版 ma-v 容器)", "/members/2421071/favourites/videos/", None, None, lambda c, b: c == 200 and 'ma-v' in b),
    ("公开用户播放列表", "/members/2421071/playlists/", None, None, lambda c, b: c == 200 and ('ma-pl' in b or 'ma-section' in b)),

    # 9. 认证与安全
    ("登录入口", "/login/", None, None, lambda c, b: c == 200 and 'login' in b),
]

def main():
    print(f"正在启动 Rule34Video 全量接口健康巡检 (目标: {BASE})...\n")
    print(f"{'测试项':<36} | {'HTTP':<5} | {'返回大小':<8} | {'断言结果'}")
    print("-" * 75)

    failed = 0
    for name, path, query, headers, check in tests:
        time.sleep(0.3)
        code, body, _ = fetch(path, query, extra_headers=headers)
        passed = check(code, body)
        status_text = "PASS" if passed else "FAIL"
        if not passed:
            failed += 1
        print(f"{name:<36} | {code:<5} | {len(body):<8} | {status_text}")

    print("-" * 75)
    if failed == 0:
        print("[SUCCESS] 全部测试项均通过，Rule34Video 接口与解析特征健康！")
        sys.exit(0)
    else:
        print(f"[WARNING] 存在 {failed} 个测试项断言失败，请检查站点是否发生结构变动！")
        sys.exit(1)

if __name__ == '__main__':
    main()
