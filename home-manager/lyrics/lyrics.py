import sys
import time
import threading
import subprocess
import requests
import json
import os
import re

STATE_FILE = "/tmp/waybar_lyrics_show"
CACHE_DIR = os.path.expanduser("~/.cache/waybar-lyrics")
P = "playerctl"
DEBUG = True

# 缓存哨兵值：标记"已确认无歌词"。写入后下次
# 播放同一首歌只需读缓存，不再发起网络请求。
NO_LYRICS_MARKER = "#NO_LYRICS#"

os.makedirs(CACHE_DIR, exist_ok=True)

# lyrics_data 的三种状态：
#   None  -> 正在后台加载中，不显示任何内容
#   []    -> 已加载，无可用的时间轴歌词
#   [...] -> 已加载，有时间轴歌词，正常滚动
last_id = ""
lyrics_data = None


def dbg(msg):
    if DEBUG:
        print(f"[DBG] {msg}", file=sys.stderr, flush=True)


def clean_text(text):
    if not text:
        return ""
    text = re.sub(
        r'\(feat\..*?\)', "", text, flags=re.IGNORECASE
    )
    text = re.sub(
        r'\(with.*?\)', "", text, flags=re.IGNORECASE
    )
    text = re.sub(r'\(.*?\)|\[.*?\]', "", text)
    text = re.sub(
        r'- .*Remaster.*', "", text, flags=re.IGNORECASE
    )
    text = re.sub(r' - Single| - Deluxe Edition', "", text)
    return text.strip()


def make_cache_path(meta):
    name = f"{meta['artist']} - {meta['title']}"
    name = re.sub(r'[\\\\/:\"*?<>|]+', "_", name)
    return os.path.join(CACHE_DIR, name + ".lrc")


def get_metadata():
    try:
        cmd = [
            P, "-p", "spotify", "metadata",
            "--format",
            "{{title}}||{{artist}}||{{mpris:length}}"
        ]
        out = subprocess.check_output(cmd, text=True).strip()
        parts = out.split("||")
        if len(parts) < 3:
            dbg("get_metadata: 字段不足 raw=" + repr(out))
            return None
        meta = {
            "title": parts[0].strip(),
            "artist": parts[1].split(",")[0].strip(),
            "duration": int(parts[2]) // 1000000
        }
        t = repr(meta["title"])
        a = repr(meta["artist"])
        d = meta["duration"]
        dbg(f"get_metadata: title={t} artist={a} {d}s")
        return meta
    except subprocess.CalledProcessError as e:
        dbg(f"get_metadata: playerctl 失败 -> {e}")
        return None
    except ValueError as e:
        dbg(f"get_metadata: 解析数值失败 -> {e}")
        return None


def score_match(item, title, artist):
    # lrclib 用 trackName/artistName；
    # meting API 用 name/title/artist/author
    name = (
        item.get("trackName")
        or item.get("name")
        or item.get("title")
        or ""
    ).lower()
    art = (
        item.get("artistName")
        or item.get("artist")
        or item.get("author")
        or ""
    ).lower()
    title_l = title.lower()
    artist_l = artist.lower()
    score = 0
    if title_l in name:
        score += 2
    if artist_l in art:
        score += 2
    if name in title_l or title_l in name:
        score += 1
    if art in artist_l or artist_l in art:
        score += 1
    return score


def generate_queries(meta):
    """供 meting 系列 API 使用的多策略查询列表"""
    title = meta["title"]
    artist = meta["artist"]
    queries = []
    queries.append(f"{title} {artist}")
    queries.append(f"{artist} {title}")
    clean_title = clean_text(title)
    queries.append(f"{clean_title} {artist}")
    queries.append(title)
    queries.append(artist)
    unique = list(dict.fromkeys(queries))
    dbg("generate_queries: " + str(unique))
    return unique


def fetch_lrclib(meta):
    dbg("fetch_lrclib: 开始")
    title = meta["title"]
    artist = meta["artist"]
    dur = meta["duration"]
    # contacted=True 表示成功拿到过有效的 JSON
    # 响应，此时"无歌词"的结论才可以信任并缓存
    contacted = False

    # Step 1: 精确查找。lrclib /api/get 会在 ± 5s
    # 内自动模糊匹配时长，是最可靠的入口。
    # 若找到 syncedLyrics 直接返回；若只有
    # plainLyrics，继续尝试搜索找有时间轴的版本。
    try:
        r = requests.get(
            "https://lrclib.net/api/get",
            params={
                "track_name": title,
                "artist_name": artist,
                "duration": dur
            },
            timeout=5
        )
        dbg(
            f"fetch_lrclib: /api/get"
            f" HTTP {r.status_code}"
        )
        if r.status_code == 200:
            contacted = True
            data = r.json()
            lrc = data.get("syncedLyrics")
            if lrc:
                dbg("fetch_lrclib: /api/get synced 命中")
                return lrc, True
            dbg("fetch_lrclib: /api/get 无 synced，转搜索")
    except requests.RequestException as e:
        dbg(f"fetch_lrclib: /api/get 异常 -> {e}")

    # Step 2: 搜索兜底，但施加严格的双重过滤。
    # 查询只用含 title+artist 的组合，绝不做
    # 单字段搜索，避免误命中同名不同曲的结果。
    queries = [
        f"{title} {artist}",
        f"{artist} {title}",
        f"{clean_text(title)} {artist}",
    ]
    queries = list(dict.fromkeys(queries))

    for q in queries:
        dbg("fetch_lrclib: search q=" + repr(q))
        try:
            r = requests.get(
                "https://lrclib.net/api/search",
                params={"q": q},
                timeout=5
            )
            dbg(f"fetch_lrclib: HTTP {r.status_code}")
            if r.status_code != 200:
                continue
            contacted = True

            results = r.json()
            dbg(f"fetch_lrclib: {len(results)} 个结果")
            if not results:
                continue

            # 时长过滤：偏差超过 3s 的大概率是不同
            # edit/版本，时间轴会对不上，直接丢弃。
            # dur==0 表示 Spotify 未提供时长，跳过。
            if dur > 0:
                dur_ok = [
                    x for x in results
                    if abs(
                        x.get("duration", 0) - dur
                    ) <= 3
                ]
            else:
                dur_ok = results
            n_dur = len(dur_ok)
            dbg(f"fetch_lrclib: 时长过滤后 {n_dur} 个")
            if not dur_ok:
                continue

            for i, item in enumerate(dur_ok[:3]):
                has_s = bool(item.get("syncedLyrics"))
                has_p = bool(item.get("plainLyrics"))
                sc = score_match(item, title, artist)
                tn = repr(item.get("trackName"))
                an = repr(item.get("artistName"))
                dbg(
                    f"  [{i}] track={tn} artist={an}"
                    f" sc={sc} s={has_s} p={has_p}"
                )

            # 双键排序：先保证 synced 优先，
            # 再在同类中选匹配分最高的版本
            best = sorted(
                dur_ok,
                key=lambda x: (
                    bool(x.get("syncedLyrics")),
                    score_match(x, title, artist)
                ),
                reverse=True
            )[0]

            sc = score_match(best, title, artist)
            # 最低匹配分 3 分：title 或 artist 至少
            # 有一个必须出现在结果字段里，得分过低
            # 的结果极可能是完全无关的歌曲
            if sc < 3:
                dbg(f"fetch_lrclib: 分数{sc}<3，跳过")
                continue

            has_s = bool(best.get("syncedLyrics"))
            has_p = bool(best.get("plainLyrics"))
            tn = repr(best.get("trackName"))
            dbg(
                f"fetch_lrclib: 选中 track={tn}"
                f" sc={sc} s={has_s} p={has_p}"
            )

            lrc = (
                best.get("syncedLyrics")
                or best.get("plainLyrics")
            )
            if lrc:
                dbg(
                    "fetch_lrclib: 成功 前50="
                    + repr(lrc[:50])
                )
                return lrc, True

        except requests.RequestException as e:
            dbg(f"fetch_lrclib: 网络异常 -> {e}")
            continue

    dbg("fetch_lrclib: 所有 query 未命中")
    return "", contacted


def _meting_search(server, meta):
    queries = generate_queries(meta)
    base = "https://metingapi.nanorocky.top/"
    contacted = False

    for q in queries:
        dbg(f"fetch_{server}: query=" + repr(q))
        try:
            r = requests.get(
                base,
                params={
                    "server": server,
                    "type": "search",
                    "id": "0",
                    "keyword": q
                },
                timeout=5
            )
            dbg(
                f"fetch_{server}:"
                f" 搜索 HTTP {r.status_code}"
            )
            if r.status_code != 200:
                continue
            contacted = True

            results = r.json()
            n = (
                len(results)
                if isinstance(results, list)
                else 0
            )
            dbg(f"fetch_{server}: {n} 个结果")
            if not results:
                continue

            best = sorted(
                results,
                key=lambda x: score_match(
                    x, meta["title"], meta["artist"]
                ),
                reverse=True
            )[0]

            # meting 结果不含时长，只能靠匹配分把关
            sc = score_match(
                best, meta["title"], meta["artist"]
            )
            if sc < 2:
                nm2 = repr(best.get("name"))
                dbg(
                    f"fetch_{server}: 分数{sc}<2"
                    f" name={nm2}，跳过"
                )
                continue

            song_id = best.get("id")
            nm = repr(best.get("name"))
            dbg(
                f"fetch_{server}:"
                f" id={song_id} name={nm}"
            )
            if not song_id:
                continue

            r2 = requests.get(
                base,
                params={
                    "server": server,
                    "type": "lrc",
                    "id": song_id
                },
                timeout=5
            )
            n2 = len(r2.text)
            dbg(
                f"fetch_{server}: 歌词"
                f" HTTP {r2.status_code} 长度={n2}"
            )
            if r2.status_code == 200 and r2.text.strip():
                return r2.text, True

        except requests.RequestException as e:
            dbg(f"fetch_{server}: 网络异常 -> {e}")
            continue

    dbg(f"fetch_{server}: 未命中")
    return "", contacted


def fetch_netease(meta):
    dbg("fetch_netease: 开始")
    return _meting_search("netease", meta)


def fetch_qq(meta):
    dbg("fetch_qq: 开始")
    return _meting_search("tencent", meta)


def fetch_online(meta):
    dbg("fetch_online: lrclib -> netease -> qq")
    any_contacted = False

    lrc, contacted = fetch_lrclib(meta)
    any_contacted = any_contacted or contacted
    if lrc:
        dbg("fetch_online: lrclib 命中")
        return lrc, True

    lrc, contacted = fetch_netease(meta)
    any_contacted = any_contacted or contacted
    if lrc:
        dbg("fetch_online: netease 命中")
        return lrc, True

    lrc, contacted = fetch_qq(meta)
    any_contacted = any_contacted or contacted
    if lrc:
        dbg("fetch_online: qq 命中")
        return lrc, True

    dbg("fetch_online: 三个源均未命中")
    return "", any_contacted


def fetch_lyrics(meta):
    path = make_cache_path(meta)
    dbg("fetch_lyrics: 缓存路径=" + path)

    if os.path.exists(path):
        dbg("fetch_lyrics: 命中缓存")
        try:
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            if content.strip() == NO_LYRICS_MARKER:
                dbg("fetch_lyrics: 缓存标记为无歌词")
                return ""
            dbg(f"fetch_lyrics: 缓存 {len(content)} 字符")
            return content
        except OSError as e:
            dbg(f"fetch_lyrics: 读缓存失败 -> {e}")
    else:
        dbg("fetch_lyrics: 无缓存，发起网络请求")

    lrc, contacted = fetch_online(meta)

    if lrc:
        try:
            with open(path, "w", encoding="utf-8") as f:
                f.write(lrc)
            dbg("fetch_lyrics: 已写入歌词缓存")
        except OSError as e:
            dbg(f"fetch_lyrics: 写缓存失败 -> {e}")
    elif contacted:
        # 至少成功联系到一个 API 并确认无歌词，
        # 写入哨兵值，下次播放同曲直接命中缓存
        try:
            with open(path, "w", encoding="utf-8") as f:
                f.write(NO_LYRICS_MARKER)
            dbg("fetch_lyrics: 已写入'无歌词'标记")
        except OSError as e:
            dbg(f"fetch_lyrics: 写缓存失败 -> {e}")
    else:
        # 三个源全部网络异常，结果不可信，
        # 不写缓存，下次播放时重新尝试
        dbg("fetch_lyrics: 网络不可达，跳过缓存写入")

    return lrc


def parse_lrc(lrc):
    lines = []
    for line in lrc.splitlines():
        m = re.match(r"\[(\d+):(\d+\.\d+)\](.*)", line)
        if m:
            sec = int(m.group(1)) * 60 + float(m.group(2))
            lines.append((sec, m.group(3).strip()))
    dbg(f"parse_lrc: {len(lines)} 行带时间轴")
    if lines:
        dbg(
            f"parse_lrc: 第一行"
            f" ts={lines[0][0]:.2f}s"
            f" text={repr(lines[0][1])}"
        )
    return lines


def fetch_lyrics_async(meta, target_id):
    # 在后台线程中完成网络请求和解析，结果写回
    # lyrics_data。写入前检查 last_id 是否仍然
    # 匹配，防止慢速请求覆盖更新歌曲的数据。
    global lyrics_data
    dbg("async: 开始 id=" + repr(target_id))
    lrc = fetch_lyrics(meta)
    parsed = parse_lrc(lrc)
    if last_id == target_id:
        # parsed 可能是 [] （无时间轴歌词），
        # 这正是我们想写入的——主循环会据此
        # 显示"无歌词"，而不是继续等待
        lyrics_data = parsed
        dbg("async: 歌词已更新 " + repr(target_id))
    else:
        dbg("async: 歌曲已切换，丢弃 " + repr(target_id))


if not os.path.exists(STATE_FILE):
    with open(STATE_FILE, "w") as f:
        f.write("true")

while True:
    try:
        with open(STATE_FILE, "r") as f:
            visible = f.read().strip() == "true"
        status = subprocess.check_output(
            [P, "-p", "spotify", "status"], text=True
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        status, visible = "Stopped", True

    meta = get_metadata()

    if status != "Playing" or not meta:
        has_meta = "有" if meta else "无"
        dbg(
            f"主循环: status={status!r}"
            f" meta={has_meta} -> 空"
        )
        print(json.dumps({"text": "", "class": "none"}))
        sys.stdout.flush()
        time.sleep(1)
        continue

    curr_id = f"{meta['title']}{meta['artist']}"

    if curr_id != last_id:
        dbg("主循环: 歌曲切换 id=" + repr(curr_id))
        last_id = curr_id
        lyrics_data = None  # 标记为加载中
        t = threading.Thread(
            target=fetch_lyrics_async,
            args=(meta, curr_id),
            daemon=True
        )
        t.start()

    # 三态分支：隐藏 / 加载中 / 无歌词 / 显示歌词
    if not visible:
        dbg("主循环: 隐藏状态 -> 空")
        print(json.dumps({"text": ""}))
    elif lyrics_data is None:
        dbg("主循环: 加载中 -> 空")
        print(json.dumps({"text": ""}))
    elif not lyrics_data:
        dbg("主循环: 无歌词")
        out = json.dumps(
            {"text": " 󰝚  "}, ensure_ascii=False
        )
        print(out)
    else:
        try:
            pos = float(subprocess.check_output(
                [P, "-p", "spotify", "position"],
                text=True
            ))
            curr_txt = ""
            for ts, txt in lyrics_data:
                if pos >= ts:
                    curr_txt = txt
                else:
                    break
            print(
                json.dumps(
                    {"text": curr_txt},
                    ensure_ascii=False
                )
            )
        except (
            subprocess.CalledProcessError,
            ValueError
        ) as e:
            dbg(f"主循环: 获取播放位置失败 -> {e}")
            print(json.dumps({"text": ""}))

    sys.stdout.flush()
    time.sleep(0.1)
