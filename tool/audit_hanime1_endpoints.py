#!/usr/bin/env python3
"""
Hanime1 (Hanime) 全量接口健康探测与自动化巡检脚本

用途：
  对 HaRu 客户端中用到的 Hanime1 关键公开端点进行自动化网络探测与结构特征断言。
  覆盖首页分区流、分页加载、综合搜索、多维筛选、视频详情/播放源、评论异步 JSON、
  公开播放列表及其分页、登录页 CSRF 令牌及用户主页等。

运行方式：
  python tool/audit_hanime1_endpoints.py
"""

import sys
import urllib.request
import urllib.parse
import json
import time
import re

# 兼容 Windows 控制台 UTF-8 输出
if sys.platform == "win32" and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

UA = (
    'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36'
)
BASE = 'https://hanime1.me'

def is_cloudflare_challenge(code, body):
    if code == 403:
        return True
    lower = body.lower()
    return any(keyword in lower for keyword in [
        'just a moment',
        'cloudflare',
        'attention required',
        'checking your browser',
        'verify you are human',
        'cf-turnstile-response',
    ])

def fetch(path, query=None, data=None, retries=2):
    url = BASE + path
    if query:
        # 支持 tags[] 和 brands[] 列表传递
        url += '?' + urllib.parse.urlencode(query, doseq=True)
    req = urllib.request.Request(url, headers={
        'User-Agent': UA,
        'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
    })
    if data:
        req.data = urllib.parse.urlencode(data).encode('utf-8')
    for attempt in range(retries + 1):
        try:
            resp = urllib.request.urlopen(req, timeout=15)
            return resp.getcode(), resp.read().decode('utf-8', errors='replace'), resp.headers
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode('utf-8', errors='replace'), e.headers
        except Exception as e:
            if attempt == retries:
                return 0, str(e), {}
            time.sleep(1)

tests = [
    # 1. 首页流媒体与分区
    (
        "首页多分区流 (第1页)",
        "/",
        None,
        lambda c, b: c == 200 and 'home-rows-videos-wrapper' in b and 'watch?v=' in b
    ),
    (
        "首页分页流 (第2页)",
        "/",
        {"page": "2"},
        lambda c, b: c == 200 and 'watch?v=' in b
    ),

    # 2. 综合搜索与多维筛选
    (
        "综合搜索 (关键字)",
        "/search",
        {"query": "妹"},
        lambda c, b: c == 200 and 'watch?v=' in b
    ),
    (
        "多维筛选 (类型 genre=3DCG)",
        "/search",
        {"genre": "3DCG"},
        lambda c, b: c == 200 and 'watch?v=' in b
    ),
    (
        "多维筛选 (排序+标签 sort & tags[])",
        "/search",
        {"sort": "latest", "tags[]": ["巨乳"]},
        lambda c, b: c == 200 and 'watch?v=' in b
    ),

    # 3. 视频详情与播放源
    (
        "视频详情与播放源 (/watch?v=)",
        "/watch",
        {"v": "39174"},
        lambda c, b: c == 200 and ('<video' in b or '.mp4' in b) and ('shareBtn-title' in b or '<h1>' in b or 'video-details-wrapper' in b)
    ),

    # 4. 视频评论系统 (异步 JSON 接口)
    (
        "主评论列表 JSON (/loadComment)",
        "/loadComment",
        {"type": "video", "id": "39174"},
        lambda c, b: c == 200 and b.strip().startswith('{') and ('comments' in b or '[]' in b)
    ),
    (
        "子评论回复 JSON (/loadReplies)",
        "/loadReplies",
        {"id": "1"},
        lambda c, b: c == 200 and b.strip().startswith('{') and ('replies' in b or '[]' in b)
    ),

    # 5. 公开播放列表与分页
    (
        "公开播放列表 (/playlist?list=)",
        "/playlist",
        {"list": "100"},
        lambda c, b: c == 200 and ('watch?v=' in b or 'playlist' in b.lower())
    ),
    (
        "公开播放列表分页 (page=2)",
        "/playlist",
        {"list": "100", "page": "2"},
        lambda c, b: c == 200 and ('watch?v=' in b or 'playlist' in b.lower())
    ),

    # 6. 认证与公开用户页
    (
        "登录页面与 CSRF 令牌 (/login)",
        "/login",
        None,
        lambda c, b: c == 200 and ('csrf-token' in b or 'name="_token"' in b)
    ),
    (
        "公开用户主页 (/user/)",
        "/user/1",
        None,
        lambda c, b: c == 200 and ('订阅者' in b or 'user' in b.lower())
    ),
]

def main():
    print(f"正在启动 Hanime1 全量公开端点健康巡检 (目标: {BASE})...\n")
    print(f"{'测试项':<38} | {'HTTP':<5} | {'返回大小':<8} | {'断言结果'}")
    print("-" * 75)

    passed_count = 0
    blocked_count = 0
    failed_count = 0

    for name, path, query, check in tests:
        code, body, _ = fetch(path, query)
        is_cf = is_cloudflare_challenge(code, body)
        passed = check(code, body)

        if passed:
            status_text = "PASS"
            passed_count += 1
        elif is_cf:
            status_text = "BLOCKED (Cloudflare)"
            blocked_count += 1
        else:
            status_text = "FAIL"
            failed_count += 1

        print(f"{name:<38} | {code:<5} | {len(body):<8} | {status_text}")

    print("-" * 75)
    print(f"巡检完成：成功通过={passed_count}，Cloudflare拦截={blocked_count}，断言失败={failed_count}")

    if failed_count > 0:
        print("[WARNING] 存在端点断言失败，请检查站点 DOM 结构或接口规范是否发生漂移！")
        sys.exit(1)
    elif blocked_count > 0:
        print("[INFO] 部分端点受到 Cloudflare 质询拦截，HaRu 客户端可在端侧通过 WebView 协调器自动解盾。")
        sys.exit(0)
    else:
        print("[SUCCESS] 全部公开端点测试项均通过，Hanime1 接口结构健康！")
        sys.exit(0)

if __name__ == '__main__':
    main()
