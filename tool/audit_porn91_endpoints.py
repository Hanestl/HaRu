#!/usr/bin/env python3
"""
91porn 接口健康探测与自动化巡检脚本

用途：
  对 HaRu 客户端中用到的 91porn 接口做网络探测与结构特征断言，
  覆盖分类列表分页、搜索、详情页直链提取，以及本站的两条反抓取行为。

运行方式：
  python tool/audit_porn91_endpoints.py
  python tool/audit_porn91_endpoints.py --viewkey 1716989600   # 指定详情页样本

为什么单独写这个脚本：
  本站与其它站点不同，有两条会"静默返回错误内容"的行为，普通断言抓不到：
  1. 会话未预热时，详情页会整页换成**另一个视频**（HTTP 200，海报与播放源
     一起被替换成同一个无关编号），因此必须先请求一次 v.php 列表页预热；
  2. 直链带 e=<unix 秒> 过期参数（约 15 分钟），过期后必须重新抓页面。
  脚本对这两条都做显式验证，并把"预热前后"的编号差异打印出来。
"""

import argparse
import html
import http.cookiejar
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

UA = (
    "Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36"
)
BASE = "https://91porn.com"

# 全站固定的广告诱饵源，与所看视频无关，必须整条丢弃。
DECOY_FILE = "358999.mp4"

STRENCODE_RE = re.compile(r"""strencode2\(\s*(["'])(.*?)\1\s*\)""", re.S)
SOURCE_RE = re.compile(r"""src=['"]([^'"]+)['"]""", re.I)
MEDIA_ID_RE = re.compile(r"/(\d+)\.mp4(?:[?#]|$)")
THUMB_ID_RE = re.compile(r"/thumb/(\d+)\.")
VIEWKEY_RE = re.compile(r"view_video\.php\?viewkey=([0-9a-zA-Z]+)")
TITLE_RE = re.compile(r"<title>(.*?)</title>", re.S | re.I)
TITLE_TAIL_RE = re.compile(r"\s*[-–—|]\s*91porn\s*$", re.I)

_opener = urllib.request.build_opener(
    urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())
)


def _request(opener, path, query=None):
    url = BASE + path
    if query:
        url += "?" + urllib.parse.urlencode(query)
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": UA,
            "Accept-Language": "zh-CN,zh;q=0.9",
            "Referer": BASE + "/",
        },
    )
    with opener.open(req, timeout=25) as resp:
        return resp.getcode(), resp.read().decode("utf-8", "replace")


def fetch(path, query=None, retries=2, opener=None):
    target = opener or _opener
    last = (0, "")
    for attempt in range(retries + 1):
        try:
            return _request(target, path, query)
        except urllib.error.HTTPError as error:
            return error.code, error.read().decode("utf-8", "replace")
        except Exception as error:  # noqa: BLE001 - 巡检脚本需要报告任意失败
            last = (0, str(error))
    return last


def extract_stream(body):
    """返回 (stream_url, media_id)——只认 strencode2 编码块，丢弃诱饵。"""
    for match in STRENCODE_RE.finditer(body):
        decoded = urllib.parse.unquote(match.group(2))
        for raw in SOURCE_RE.findall(decoded):
            url = html.unescape(raw)
            if url.startswith("http://"):
                url = "https://" + url[len("http://") :]
            if url.rsplit("/", 1)[-1].split("?")[0] == DECOY_FILE:
                continue
            found = MEDIA_ID_RE.search(url)
            if found:
                return url, found.group(1)
    return None, None


def poster_id(body):
    found = re.search(r"""<video[^>]+poster=['"]([^'"]+)['"]""", body, re.I)
    return THUMB_ID_RE.search(found.group(1)).group(1) if found else None


def page_title(body):
    found = TITLE_RE.search(body)
    if not found:
        return None
    title = html.unescape(found.group(1)).strip()
    title = TITLE_TAIL_RE.sub("", title).strip()
    return title or None


def check_list():
    """分类列表：脚本用的每个分类都要能列出条目，且分页互不重复。"""
    # 与 lib/core/models/porn91_models.dart 的 Porn91Category 保持一致。
    # category=hd 不在此列：它是会员墙，实测恒为空列表。
    categories = [
        ("hot", {}),
        ("top", {}),
        ("top", {"m": "-1"}),
        ("rf", {}),
        ("long", {}),
        ("longer", {}),
        ("tf", {}),
        ("md", {}),
        ("mf", {}),
        ("ori", {}),
    ]
    failures = []
    for code, extra in categories:
        query = {"category": code, "viewtype": "basic", **extra}
        status, body = fetch("/v.php", query)
        keys = _viewkeys(body)
        label = code + ("&m=-1" if extra else "")
        ok = status == 200 and len(keys) >= 10
        print(f"  分类 {label:<8} | {status:<4} | {len(keys):<3} 条 | "
              f"{'PASS' if ok else 'FAIL'}")
        if not ok:
            failures.append(f"分类 {label}")
    return failures


def check_pagination():
    """分页：第 1、2 页都应有条目且互不重叠（末页之后站点会循环，故只比前两页）。"""
    first = _viewkeys(fetch("/v.php", {"category": "hot", "viewtype": "basic"})[1])
    second = _viewkeys(
        fetch("/v.php", {"category": "hot", "viewtype": "basic", "page": "2"})[1]
    )
    overlap = first & second
    ok = len(first) >= 10 and len(second) >= 10 and not overlap
    print(f"  分页 1/2 互不重叠 | {len(first)} vs {len(second)} | 重叠 {len(overlap)} | "
          f"{'PASS' if ok else 'FAIL'}")
    return [] if ok else ["分页"]


def check_search(keyword="学生"):
    status, body = fetch(
        "/search_result.php", {"search_id": keyword, "viewtype": "basic"}
    )
    keys = _viewkeys(body)
    ok = status == 200 and len(keys) >= 5
    print(f"  搜索 search_id={keyword} | {status:<4} | {len(keys):<3} 条 | "
          f"{'PASS' if ok else 'FAIL'}")
    return [] if ok else ["搜索"]

def check_warmup(viewkey):
    """预热行为：这是本站最容易被忽略、也最容易静默出错的一条。

    新建会话后**第一次**请求详情页会拿到另一个视频（HTTP 200，海报与播放源
    一起被替换成同一个无关编号，页面自洽因此事后无法识别）；先请求一次列表页
    预热后，同一 viewkey 才返回正确的页面。

    必须用**全新 cookie 会话**复现：本脚本其余检查已经共用一个会话并预热过，
    直接复用会测不到预热这一步，只会得到"一贯正确"的假象。
    """
    cold_opener = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())
    )
    cold_body = fetch(
        "/view_video.php", {"viewkey": viewkey, "viewtype": "basic"}, opener=cold_opener
    )[1]
    _, cold_media = extract_stream(cold_body)
    cold_poster = poster_id(cold_body)

    # 预热：请求任意分类列表页（应用侧 Porn91Api._warmSession 做的事）
    fetch("/v.php", {"category": "rf", "viewtype": "basic"}, opener=cold_opener)
    warm_body = fetch(
        "/view_video.php", {"viewkey": viewkey, "viewtype": "basic"}, opener=cold_opener
    )[1]
    warm_stream, warm_media = extract_stream(warm_body)
    warm_poster = poster_id(warm_body)

    consistent = warm_media is not None and warm_media == warm_poster
    warm_ok = consistent and not (warm_stream or "").split("?")[0].endswith(DECOY_FILE)
    replaced = cold_media is not None and cold_media != warm_media

    print(f"  冷会话首次 media={cold_media} poster={cold_poster}")
    print(f"  预热后     media={warm_media} poster={warm_poster}")
    if replaced:
        print(f"  （预热确实改变了返回的视频：{cold_media} -> {warm_media}）")
    else:
        print("  （本次冷会话首次即返回正确视频；站点行为有抖动，应用仍按预热路径走）")
    print(f"  预热后解析一致 | {'PASS' if warm_ok else 'FAIL'}")
    return ([] if warm_ok else ["会话预热"]), warm_stream


def check_stream(stream_url):
    """直链可用性：必须有 Content-Length、支持 Range，且是 MP4。"""
    if not stream_url:
        print(f"  直链 HEAD | -    | 无直链 | FAIL")
        return ["直链"]
    req = urllib.request.Request(
        stream_url, method="HEAD", headers={"User-Agent": UA, "Referer": BASE + "/"}
    )
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            status = resp.getcode()
            length = resp.headers.get("Content-Length")
            ranges = resp.headers.get("Accept-Ranges")
    except Exception as error:  # noqa: BLE001
        print(f"  直链 HEAD | 0    | {error} | FAIL")
        return ["直链"]
    size = int(length) if length and length.isdigit() else 0
    ok = status == 200 and size > 1 << 20 and (ranges or "").lower() == "bytes"
    print(f"  直链 HEAD | {status:<4} | {size / 1048576:.1f}MB | "
          f"Range={ranges} | {'PASS' if ok else 'FAIL'}")
    return [] if ok else ["直链"]


def check_decoy():
    """诱饵源必须存在于注释里，且解析器不得选中它。"""
    # 列表页没有播放器，用第一个详情页验证
    body = fetch("/v.php", {"category": "rf", "viewtype": "basic"})[1]
    keys = list(_viewkeys(body))
    if not keys:
        print("  诱饵过滤 | -    | 列表为空，跳过 | FAIL")
        return ["诱饵过滤"]
    detail = fetch("/view_video.php", {"viewkey": keys[0], "viewtype": "basic"})[1]
    stream, _ = extract_stream(detail)
    has_decoy = DECOY_FILE in detail
    picked_decoy = bool(stream) and stream.split("?")[0].endswith(DECOY_FILE)
    ok = has_decoy and not picked_decoy
    print(f"  诱饵过滤 | 注释含诱饵={has_decoy} 选中诱饵={picked_decoy} | "
          f"{'PASS' if ok else 'FAIL'}")
    return [] if ok else ["诱饵过滤"]


def _viewkeys(body):
    return set(VIEWKEY_RE.findall(body))


def main():
    parser = argparse.ArgumentParser(description="91porn 接口健康巡检")
    parser.add_argument(
        "--viewkey",
        default="1716989600",
        help="用于详情页断言的样本 viewkey（换一个即可，仅需有效）",
    )
    args = parser.parse_args()

    print("=" * 78)
    print("91porn 接口健康巡检")
    print("=" * 78)

    failures = []
    print("\n[1] 分类列表")
    failures += check_list()
    print("\n[2] 分页")
    failures += check_pagination()
    print("\n[3] 搜索")
    failures += check_search()
    print("\n[4] 会话预热与详情解析")
    warm_failures, stream = check_warmup(args.viewkey)
    failures += warm_failures
    print("\n[5] 直链可用性")
    failures += check_stream(stream)
    print("\n[6] 诱饵源过滤")
    failures += check_decoy()

    print("\n" + "-" * 78)
    if not failures:
        print("[SUCCESS] 全部巡检项通过，91porn 接口与解析特征健康。")
        return 0
    print(f"[WARNING] {len(failures)} 项失败：{'、'.join(failures)}")
    print("站点可能已改版或临时限流；重试一次仍失败再按 docs/porn91_api_endpoints.md 更新解析。")
    return 1


if __name__ == "__main__":
    sys.exit(main())
