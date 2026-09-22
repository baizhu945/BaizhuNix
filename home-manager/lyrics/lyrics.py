"""Waybar Spotify lyrics module.

The module deliberately keeps all network work off the polling loop.  Spotify
can expose a different track while an old request is still in flight, so every
request is associated with a stable track key before its result is accepted.
"""

import bisect
import contextlib
import difflib
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import queue
import re
import subprocess
import sys
import tempfile
import threading
import time
import unicodedata

import requests


# Runtime configuration can be overridden without changing the Nix expression.
PLAYER = os.environ.get("WAYBAR_LYRICS_PLAYER", "spotify")
PLAYERCTL = os.environ.get("WAYBAR_LYRICS_PLAYERCTL", "playerctl")
# Keep the original path for compatibility with an already-running Waybar
# process.  It is also overridable for testing or a private user session.
STATE_FILE = Path(
    os.environ.get("WAYBAR_LYRICS_STATE", "/tmp/waybar_lyrics_show")
)
CACHE_DIR = Path(
    os.environ.get(
        "WAYBAR_LYRICS_CACHE_DIR",
        os.path.join(
            os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
            "waybar-lyrics",
        ),
    )
)
DEBUG = os.environ.get("WAYBAR_LYRICS_DEBUG", "").lower() in {
    "1",
    "true",
    "yes",
    "on",
}
LANGUAGE_OVERRIDE = os.environ.get("WAYBAR_LYRICS_LANGUAGE", "").lower()

POLL_INTERVAL = 0.25
INACTIVE_INTERVAL = 1.0
RETRY_INTERVAL = 30.0
HTTP_TIMEOUT = (2.0, 5.0)
FETCH_DEADLINE = 15.0
# Bump this whenever candidate validation changes so previously selected
# potentially incomplete or wrongly localized timelines are evaluated again.
CACHE_VERSION = 5
POSITIVE_CACHE_TTL = 30 * 24 * 60 * 60
PLAIN_CACHE_TTL = 7 * 24 * 60 * 60
NEGATIVE_CACHE_TTL = 60 * 60
MAX_LYRICS_BYTES = 512 * 1024

LRCLIB_GET_URL = "https://lrclib.net/api/get"
LRCLIB_SEARCH_URL = "https://lrclib.net/api/search"
METING_URL = "https://metingapi.nanorocky.top/"

FIELD_SEPARATOR = "\x1f"
NO_LYRICS_MARKER = "#NO_LYRICS#"

# Standard LRC timestamps.  Both [mm:ss] and [mm:ss.xx] are common; a few
# providers use h:mm:ss or a colon instead of a dot before milliseconds.
TIMESTAMP_RE = re.compile(
    r"\[(?:(\d{1,3}):)?(\d{1,4}):(\d{1,2})"
    r"(?:[\.,:](\d{1,3}))?\]"
)
OFFSET_RE = re.compile(
    r"^\s*\[offset\s*:\s*([-+]?\d+(?:\.\d+)?)\]\s*$",
    re.IGNORECASE,
)
LENGTH_RE = re.compile(
    r"^\s*\[length\s*:\s*(?:(\d{1,3}):)?(\d{1,4}):(\d{1,2})"
    r"(?:[\.,:](\d{1,3}))?\]\s*$",
    re.IGNORECASE,
)
META_TAG_RE = re.compile(r"^\s*\[[A-Za-z][^:]*:.*\]\s*$")
INLINE_META_TAG_RE = re.compile(r"\[[A-Za-z][^:]*:[^\]]*\]")
KARAOKE_TAG_RE = re.compile(
    r"<(?:(\d{1,3}):)?\d{1,4}:\d{1,2}"
    r"(?:[\.,:]\d{1,3})?>"
)
ARTIST_SEPARATOR_RE = re.compile(r"\s*(?:,|、|;)\s*")


def dbg(message):
    if DEBUG:
        print(f"[waybar-lyrics] {message}", file=sys.stderr, flush=True)


def run_playerctl(arguments, timeout=1.0):
    """Run playerctl and return stripped stdout, or raise its normal errors."""
    return subprocess.run(
        [PLAYERCTL, "-p", PLAYER, *arguments],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    ).stdout.strip()


def split_artists(value):
    if not value:
        return []
    return [
        part.strip()
        for part in ARTIST_SEPARATOR_RE.split(value)
        if part.strip()
    ]


def parse_mpris_duration(value):
    """MPRIS length is microseconds; tolerate seconds for unusual players."""
    try:
        number = float(str(value).strip())
    except (TypeError, ValueError):
        return 0.0
    if not math.isfinite(number) or number <= 0:
        return 0.0
    # MPRIS uses microseconds and normal tracks are well above 10,000 units.
    return number / 1_000_000.0 if number > 10_000 else number


def parse_source_duration(value):
    """Accept seconds, milliseconds, or microseconds returned by providers."""
    try:
        number = float(str(value).strip())
    except (TypeError, ValueError):
        return 0.0
    if not math.isfinite(number) or number <= 0:
        return 0.0
    if number > 10_000_000:
        return number / 1_000_000.0
    if number > 10_000:
        return number / 1_000.0
    return number


def get_metadata():
    """Read status, identity, title and duration in one playerctl call."""
    metadata_format = FIELD_SEPARATOR.join(
        (
            "{{status}}",
            "{{mpris:trackid}}",
            "{{title}}",
            "{{artist}}",
            "{{album}}",
            "{{mpris:length}}",
        )
    )
    try:
        output = run_playerctl(
            ["metadata", "--format", metadata_format], timeout=1.0
        )
        fields = output.split(FIELD_SEPARATOR, 5)
        if len(fields) != 6:
            dbg(f"metadata fields are incomplete: {output!r}")
            return None

        status, track_id, title, artist_value, album, length = fields
        title = title.strip()
        artist_value = artist_value.strip()
        if not title or not artist_value:
            return None

        artists = split_artists(artist_value)
        artist = artists[0] if artists else artist_value
        return {
            "status": status.strip(),
            "track_id": track_id.strip(),
            "title": title,
            "artist": artist,
            "artist_value": artist_value,
            "artists": artists or [artist],
            "album": album.strip(),
            "duration": parse_mpris_duration(length),
        }
    except (
        OSError,
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
        ValueError,
    ) as error:
        dbg(f"get_metadata failed: {error}")
        return None


def normalize_match_text(value):
    value = unicodedata.normalize("NFKC", str(value or "")).casefold()
    value = value.replace("&", " and ")
    # Keep Unicode letters/numbers (important for Japanese and Chinese), but
    # discard punctuation and spacing so different providers compare equally.
    return re.sub(r"[^\w]+", "", value, flags=re.UNICODE).replace("_", "")


def script_counts(text):
    counts = {
        "latin": 0,
        "kana": 0,
        "han": 0,
        "hangul": 0,
        "cyrillic": 0,
        "arabic": 0,
        "thai": 0,
        "devanagari": 0,
    }
    for char in str(text or ""):
        codepoint = ord(char)
        name = unicodedata.name(char, "")
        if "LATIN" in name:
            counts["latin"] += 1
        elif 0x3040 <= codepoint <= 0x30FF:
            counts["kana"] += 1
        elif (
            0x3400 <= codepoint <= 0x4DBF
            or 0x4E00 <= codepoint <= 0x9FFF
        ):
            counts["han"] += 1
        elif 0xAC00 <= codepoint <= 0xD7AF:
            counts["hangul"] += 1
        elif 0x0400 <= codepoint <= 0x04FF:
            counts["cyrillic"] += 1
        elif 0x0600 <= codepoint <= 0x06FF:
            counts["arabic"] += 1
        elif 0x0E00 <= codepoint <= 0x0E7F:
            counts["thai"] += 1
        elif 0x0900 <= codepoint <= 0x097F:
            counts["devanagari"] += 1
    return counts


def lyric_language(raw_lrc):
    counts = script_counts(raw_lrc)
    if counts["kana"] >= 3:
        return "ja"
    if counts["hangul"] >= 3:
        return "ko"
    if counts["han"] >= 3:
        return "cjk"
    if counts["cyrillic"] >= 3:
        return "cyrillic"
    if counts["arabic"] >= 3:
        return "arabic"
    if counts["thai"] >= 3:
        return "thai"
    if counts["devanagari"] >= 3:
        return "devanagari"
    if counts["latin"] >= 5:
        return "latin"
    return "unknown"


def candidate_language_consensus(items, meta):
    """Find a strong language consensus among same-track API candidates."""
    counts = {}
    total = 0
    for item in items:
        if not isinstance(item, dict) or not item.get("syncedLyrics"):
            continue
        title, artist = result_fields(item)
        if (
            not title
            or not artist
            or not candidate_is_acceptable(item, meta)
            or not duration_matches(
                item.get("duration"), meta["duration"]
            )
        ):
            continue
        profile = lyric_language(item.get("syncedLyrics", ""))
        if profile == "unknown":
            continue
        counts[profile] = counts.get(profile, 0) + 1
        total += 1

    if not counts:
        return None
    profile, count = max(counts.items(), key=lambda pair: pair[1])
    second = max(
        (value for key, value in counts.items() if key != profile),
        default=0,
    )
    if count >= 2 and count >= second + 1 and count / total >= 0.6:
        return profile
    return None


def metadata_language_hint(meta):
    """Infer language from artist/album first; title is only weak evidence."""
    if LANGUAGE_OVERRIDE in {
        "ja",
        "zh",
        "cjk",
        "ko",
        "cyrillic",
        "arabic",
        "thai",
        "devanagari",
    }:
        return ("cjk" if LANGUAGE_OVERRIDE == "zh" else LANGUAGE_OVERRIDE), 1.0

    strong_text = " ".join(
        (meta.get("artist_value", ""), meta.get("album", ""))
    )
    strong_counts = script_counts(strong_text)
    weak_counts = script_counts(meta.get("title", ""))

    if strong_counts["kana"] >= 2:
        return "ja", 1.0
    if strong_counts["hangul"] >= 2:
        return "ko", 1.0
    if strong_counts["han"] >= 2:
        return "cjk", 1.0
    if strong_counts["cyrillic"] >= 2:
        return "cyrillic", 1.0
    if strong_counts["arabic"] >= 2:
        return "arabic", 1.0
    if strong_counts["thai"] >= 2:
        return "thai", 1.0
    if strong_counts["devanagari"] >= 2:
        return "devanagari", 1.0

    # A title such as "UNITE" gives no useful language evidence.  A title
    # written in kana/Han can still be a useful fallback, but must not override
    # a conflicting artist/album signal.
    if weak_counts["kana"] >= 2:
        return "ja", 0.35
    if weak_counts["hangul"] >= 2:
        return "ko", 0.35
    if weak_counts["han"] >= 2:
        return "cjk", 0.35
    return None, 0.0


TRANSLATION_MARKER_RE = re.compile(
    r"\b(?:english|translation|translated|romanized|romaji|"
    r"romanisation|transliteration)\b|英訳|翻訳|罗马音|拼音",
    re.IGNORECASE,
)


def strongly_mismatched_language(raw_lrc, item, meta):
    _target, strength = metadata_language_hint(meta)
    return (
        strength >= 0.5
        and language_preference(raw_lrc, item, meta) < 0
    )


def language_preference(raw_lrc, item, meta, consensus=None):
    target, strength = metadata_language_hint(meta)
    if consensus and strength < 0.5:
        target, strength = consensus, 0.65
    actual = lyric_language(raw_lrc)
    score = 0.0
    if target:
        compatible = {
            "ja": {"ja": 1.0, "cjk": 0.55},
            "cjk": {"cjk": 1.0, "ja": 0.85},
            "ko": {"ko": 1.0},
            "cyrillic": {"cyrillic": 1.0},
            "arabic": {"arabic": 1.0},
            "thai": {"thai": 1.0},
            "devanagari": {"devanagari": 1.0},
        }
        if actual in compatible.get(target, {}):
            score = compatible[target][actual]
        elif actual == "latin":
            score = -1.0
        score *= strength

    if isinstance(item, dict):
        item_text = " ".join(
            str(item.get(key, ""))
            for key in ("trackName", "artistName", "albumName")
        )
        if TRANSLATION_MARKER_RE.search(item_text):
            score -= 0.75
    return score


def clean_text(text):
    """Remove only common feature/remaster suffixes for fallback searches."""
    text = unicodedata.normalize("NFKC", str(text or ""))
    text = re.sub(
        r"\s*[\(\[]\s*(?:feat\.?|ft\.?|featuring|with)\b.*?[\)\]]",
        "",
        text,
        flags=re.IGNORECASE,
    )
    text = re.sub(
        r"\s+(?:feat\.?|ft\.?|featuring)\s+.*$",
        "",
        text,
        flags=re.IGNORECASE,
    )
    text = re.sub(
        r"\s*[-–—]\s*(?:(?:19|20)\d{2}\s*)?"
        r"(?:remaster(?:ed)?|radio\s+edit|single\s+version|"
        r"album\s+version)\b.*$",
        "",
        text,
        flags=re.IGNORECASE,
    )
    return re.sub(r"\s+", " ", text).strip()


def text_similarity(left, right):
    left = normalize_match_text(left)
    right = normalize_match_text(right)
    if not left or not right:
        return 0.0
    if left == right:
        return 1.0
    return difflib.SequenceMatcher(
        None, left, right, autojunk=False
    ).ratio()


def title_similarity(expected, candidate):
    return max(
        text_similarity(expected, candidate),
        text_similarity(clean_text(expected), clean_text(candidate)),
    )


def artist_similarity(expected, candidate):
    expected_values = split_artists(expected) or [str(expected or "")]
    candidate_values = split_artists(candidate) or [str(candidate or "")]
    return max(
        (
            text_similarity(left, right)
            for left in expected_values
            for right in candidate_values
        ),
        default=0.0,
    )


def result_fields(item):
    """Extract the provider-specific title and artist fields."""
    if not isinstance(item, dict):
        return "", ""

    title = (
        item.get("trackName")
        or item.get("name")
        or item.get("title")
        or ""
    )
    artist = (
        item.get("artistName")
        or item.get("artist")
        or item.get("author")
        or ""
    )
    if isinstance(title, (list, tuple)):
        title = " ".join(str(part) for part in title)
    if isinstance(artist, (list, tuple)):
        artist = ", ".join(str(part) for part in artist)
    return str(title), str(artist)


def result_match(item, meta):
    title, artist = result_fields(item)
    title_score = title_similarity(meta["title"], title)
    artist_score = artist_similarity(meta["artist_value"], artist)
    combined = title_score * 0.65 + artist_score * 0.35
    return title_score, artist_score, combined


def candidate_is_acceptable(item, meta):
    title_score, artist_score, combined = result_match(item, meta)
    # Search APIs often add a harmless version suffix, but a result with only
    # one matching field is too risky to use for a time axis.
    return (
        title_score >= 0.72
        and artist_score >= 0.50
        and combined >= 0.66
    )


def duration_matches(candidate, expected):
    candidate = parse_source_duration(candidate)
    if candidate <= 0 or expected <= 0:
        return True
    tolerance = max(4.0, expected * 0.02)
    return abs(candidate - expected) <= tolerance


def generate_queries(meta):
    title = meta["title"]
    artist = meta["artist"]
    base_title = clean_text(title)
    queries = [f"{title} {artist}"]
    if base_title and base_title != title:
        queries.append(f"{base_title} {artist}")
    # Keep the artist in every query.  A title-only search is a frequent cause
    # of same-name songs being paired with the wrong LRC file.
    return list(
        dict.fromkeys(query.strip() for query in queries if query.strip())
    )


def declared_lrc_duration(lrc):
    if not isinstance(lrc, str):
        return 0.0
    for raw_line in lrc.lstrip("\ufeff").splitlines():
        match = LENGTH_RE.match(raw_line)
        if not match:
            continue
        hours = int(match.group(1) or 0)
        minutes = int(match.group(2))
        seconds = int(match.group(3))
        fraction_text = match.group(4) or ""
        if seconds >= 60:
            return 0.0
        fraction = (
            int(fraction_text) / (10 ** len(fraction_text))
            if fraction_text
            else 0.0
        )
        return hours * 3600.0 + minutes * 60.0 + seconds + fraction
    return 0.0


def parse_lrc(lrc):
    """Parse LRC into sorted (seconds, text) pairs.

    Handles integer timestamps, comma/dot milliseconds, multiple timestamps
    on one line, and the standard [offset:milliseconds] metadata tag.
    """
    if not isinstance(lrc, str):
        return []

    lrc = lrc.lstrip("\ufeff")
    offset_seconds = 0.0
    for raw_line in lrc.splitlines():
        offset_match = OFFSET_RE.match(raw_line)
        if offset_match:
            try:
                offset_seconds = float(offset_match.group(1)) / 1000.0
            except ValueError:
                pass
            break

    parsed = []
    for raw_line in lrc.splitlines():
        timestamp_matches = list(TIMESTAMP_RE.finditer(raw_line))
        if not timestamp_matches:
            continue

        text = TIMESTAMP_RE.sub("", raw_line)
        text = INLINE_META_TAG_RE.sub("", text)
        text = KARAOKE_TAG_RE.sub("", text)
        text = re.sub(r"\s+", " ", text).strip()
        if not text:
            continue

        for match in timestamp_matches:
            hours = int(match.group(1) or 0)
            minutes = int(match.group(2))
            seconds = int(match.group(3))
            fraction_text = match.group(4) or ""
            if seconds >= 60:
                continue
            fraction = (
                int(fraction_text) / (10 ** len(fraction_text))
                if fraction_text
                else 0.0
            )
            timestamp = (
                hours * 3600.0
                + minutes * 60.0
                + seconds
                + fraction
                + offset_seconds
            )
            if not math.isfinite(timestamp) or timestamp < 0:
                continue
            parsed.append((round(timestamp, 3), text))

    parsed.sort(key=lambda pair: pair[0])
    # A few sources repeat the same timestamp/text; removing exact duplicates
    # makes selection deterministic without deleting simultaneous translations.
    unique = []
    seen = set()
    for timestamp, text in parsed:
        key = (timestamp, text)
        if key not in seen:
            unique.append((timestamp, text))
            seen.add(key)

    dbg(f"parse_lrc: {len(unique)} timed lines")
    return unique


def plain_text_from_lrc(lrc):
    if not isinstance(lrc, str):
        return ""
    if len(lrc.encode("utf-8", errors="ignore")) > MAX_LYRICS_BYTES:
        return ""

    lines = []
    for raw_line in lrc.lstrip("\ufeff").splitlines():
        if OFFSET_RE.match(raw_line) or META_TAG_RE.match(raw_line):
            continue
        line = TIMESTAMP_RE.sub("", raw_line)
        line = INLINE_META_TAG_RE.sub("", line)
        line = KARAOKE_TAG_RE.sub("", line)
        line = re.sub(r"\s+", " ", line).strip()
        if line:
            lines.append(line)

    text = "\n".join(lines).strip()
    if not text or "<html" in text[:500].lower():
        return ""
    # Never cache an API error page as if it were a plain lyric.
    if text.lower().startswith(("error ", "<!doctype", "{\"error")):
        return ""
    return text


def timeline_score(lines, duration, source_duration=0.0):
    """Estimate how completely a timed lyric covers its track."""
    if not lines:
        return 0.0
    expected = source_duration if source_duration > 0 else duration
    if expected <= 0:
        return 1.0
    coverage = min(1.0, max(0.0, lines[-1][0] / expected))
    # Do not require a fixed lyric line count: long lines and instrumental
    # sections are legitimate.  This is only a tie-breaker for duplicate
    # provider entries, while coverage remains the dominant signal.
    expected_lines = max(8.0, expected / 8.0)
    density = min(1.0, len(lines) / expected_lines)
    return coverage * 0.75 + density * 0.25


def timeline_is_plausible(lines, duration, source_duration=0.0):
    """Reject an LRC from a different edit or a severely truncated track."""
    if not lines:
        return False
    timestamps = [timestamp for timestamp, _ in lines]
    if any(
        not math.isfinite(timestamp)
        or timestamp < 0
        or timestamp > 24 * 60 * 60
        for timestamp in timestamps
    ):
        return False

    expected = source_duration if source_duration > 0 else duration
    if expected <= 0:
        return True
    if expected >= 60.0 and len(lines) < 2:
        dbg("reject sparse timeline: fewer than two lyric lines")
        return False

    tolerance = max(12.0, expected * 0.08)
    last_timestamp = timestamps[-1]
    if last_timestamp > expected + tolerance:
        dbg(
            f"reject timeline: last={last_timestamp:.1f}s "
            f"expected={expected:.1f}s"
        )
        return False

    # Lyrics can end before an instrumental outro, but a file ending in the
    # first third of a normal song is almost always the wrong version or a
    # truncated response.  Allow up to 90 seconds of legitimate outro.
    if expected >= 120.0:
        minimum_last = max(20.0, expected - max(90.0, expected * 0.30))
        if last_timestamp < minimum_last:
            dbg(
                f"reject truncated timeline: last={last_timestamp:.1f}s "
                f"minimum={minimum_last:.1f}s"
            )
            return False
    return True


def prepare_result(raw_lrc, meta, source, source_duration=0.0):
    """Validate and turn provider output into a result consumed by Waybar."""
    if not isinstance(raw_lrc, str):
        return None
    raw_lrc = raw_lrc.strip()
    if not raw_lrc or raw_lrc == NO_LYRICS_MARKER:
        return None
    if len(raw_lrc.encode("utf-8", errors="ignore")) > MAX_LYRICS_BYTES:
        dbg(f"reject oversized lyrics from {source}")
        return None
    provider_duration = parse_source_duration(source_duration)
    declared_duration = declared_lrc_duration(raw_lrc)
    if provider_duration <= 0:
        provider_duration = declared_duration
    elif (
        declared_duration > 0
        and not duration_matches(declared_duration, meta["duration"])
    ):
        dbg(f"reject declared-duration mismatch from {source}")
        return None
    if not duration_matches(provider_duration, meta["duration"]):
        dbg(f"reject duration-mismatched lyrics from {source}")
        return None

    lines = parse_lrc(raw_lrc)
    if lines:
        if not timeline_is_plausible(
            lines, meta["duration"], provider_duration
        ):
            return None
        return {
            "kind": "timed",
            "lines": lines,
            "timestamps": [timestamp for timestamp, _ in lines],
            "timeline_score": timeline_score(
                lines, meta["duration"], provider_duration
            ),
            "language": lyric_language(raw_lrc),
            "source": source,
            "raw": raw_lrc,
        }

    # A response containing timestamps but failing validation must not be
    # downgraded to plain text: that would hide a wrong time axis as a success.
    if TIMESTAMP_RE.search(raw_lrc):
        return None
    plain = plain_text_from_lrc(raw_lrc)
    if plain:
        return {
            "kind": "plain",
            "text": plain,
            "language": lyric_language(raw_lrc),
            "source": source,
            "raw": raw_lrc,
        }
    return None


def timed_result_rank(
    result, item, meta, priority=0.0, language_hint=None
):
    """Rank already-validated timed candidates without trusting API order."""
    _title_score, _artist_score, match_score = result_match(item, meta)
    language_score = language_preference(
        result["raw"], item, meta, language_hint
    )
    source_duration = (
        parse_source_duration(item.get("duration"))
        if isinstance(item, dict)
        else 0.0
    )
    duration_score = 1.0
    if source_duration > 0 and meta["duration"] > 0:
        difference = abs(source_duration - meta["duration"])
        tolerance = max(4.0, meta["duration"] * 0.02)
        duration_score = max(0.0, 1.0 - difference / tolerance)
    return (
        result.get("timeline_score", 0.0) * 100.0
        + language_score * 35.0
        + match_score * 10.0
        + duration_score * 5.0
        + priority,
        result.get("timeline_score", 0.0),
        language_score,
        match_score,
        priority,
    )


session = requests.Session()
session.headers.update(
    {
        "User-Agent": "waybar-lyrics/2.0 (+https://lrclib.net/)",
        "Accept": "application/json, text/plain;q=0.9, */*;q=0.8",
    }
)
request_deadline = None


def request_timeout():
    if request_deadline is None:
        return HTTP_TIMEOUT
    remaining = request_deadline - time.monotonic()
    if remaining <= 0.05:
        return None
    return min(HTTP_TIMEOUT[0], remaining), min(HTTP_TIMEOUT[1], remaining)


def request_json(url, params):
    timeout = request_timeout()
    if timeout is None:
        return None, False
    try:
        response = session.get(url, params=params, timeout=timeout)
        dbg(f"GET {url} -> HTTP {response.status_code}")
        if response.status_code == 404:
            # A valid provider response with no match is cacheable for a short
            # negative TTL; transport/server errors are not.
            return None, True
        if response.status_code != 200:
            return None, False
        try:
            return response.json(), True
        except (TypeError, ValueError) as error:
            dbg(f"invalid JSON from {url}: {error}")
            return None, False
    except requests.RequestException as error:
        dbg(f"request failed {url}: {error}")
        return None, False


def request_text(url, params):
    timeout = request_timeout()
    if timeout is None:
        return "", False
    try:
        response = session.get(url, params=params, timeout=timeout)
        dbg(f"GET {url} -> HTTP {response.status_code}")
        if response.status_code == 404:
            return "", True
        if response.status_code != 200:
            return "", False
        return response.text, True
    except requests.RequestException as error:
        dbg(f"request failed {url}: {error}")
        return "", False


def lrclib_candidate(item, meta, source):
    if not isinstance(item, dict):
        return None
    title, artist = result_fields(item)
    if title and artist and not candidate_is_acceptable(item, meta):
        dbg(
            f"skip LRCLIB candidate {title!r} / {artist!r}: "
            f"match={result_match(item, meta)}"
        )
        return None
    source_duration = parse_source_duration(item.get("duration"))
    synced = item.get("syncedLyrics")
    if synced and strongly_mismatched_language(synced, item, meta):
        dbg("skip LRCLIB candidate with a strong language mismatch")
        return None
    plain = item.get("plainLyrics")
    if synced:
        result = prepare_result(synced, meta, source, source_duration)
        if result:
            return result
        # Do not treat an invalid synced file as plain text.
        return None
    if plain:
        return prepare_result(plain, meta, source, source_duration)
    return None


def fetch_lrclib(meta):
    """Prefer synced LRCLIB data, retaining plain text as a last resort."""
    contacted = False
    plain_fallback = None
    exact_uncertain = False
    exact_language_blocked = False
    best_timed = None
    best_item = None
    best_priority = 0.0
    best_rank = None

    data, responded = request_json(
        LRCLIB_GET_URL,
        {
            "track_name": meta["title"],
            "artist_name": meta["artist"],
            "duration": round(meta["duration"], 3),
        },
    )
    contacted = contacted or responded
    if isinstance(data, dict):
        source = f"lrclib:get:{data.get('id', 'unknown')}"
        title, artist = result_fields(data)
        exact_match = (
            not title
            or not artist
            or candidate_is_acceptable(data, meta)
        )
        synced = data.get("syncedLyrics") if exact_match else None
        if synced:
            result = prepare_result(
                synced,
                meta,
                source,
                parse_source_duration(data.get("duration")),
            )
            if result and result["kind"] == "timed":
                if strongly_mismatched_language(synced, data, meta):
                    exact_language_blocked = True
                    dbg("withhold exact LRCLIB candidate with wrong language")
                elif (
                    metadata_language_hint(meta)[1] < 0.5
                    and lyric_language(synced) == "latin"
                ):
                    # A Latin-only exact result can be a translation/romaji
                    # record.  Wait for search consensus before accepting it.
                    exact_uncertain = True
                    best_timed = result
                    best_item = data
                    best_priority = 1.0
                else:
                    best_timed = result
                    best_item = data
                    best_priority = 1.0
                    best_rank = timed_result_rank(
                        result, data, meta, 1.0
                    )
        plain = data.get("plainLyrics") if exact_match else None
        if plain and not exact_uncertain and not exact_language_blocked:
            plain_fallback = prepare_result(
                plain,
                meta,
                source,
                parse_source_duration(data.get("duration")),
            )

    for query in generate_queries(meta)[:2]:
        data, responded = request_json(LRCLIB_SEARCH_URL, {"q": query})
        contacted = contacted or responded
        if not isinstance(data, list) or not data:
            continue

        ranked = []
        for item in data:
            if not isinstance(item, dict):
                continue
            title, artist = result_fields(item)
            if (
                not title
                or not artist
                or not candidate_is_acceptable(item, meta)
            ):
                continue
            candidate_duration = parse_source_duration(item.get("duration"))
            if not duration_matches(candidate_duration, meta["duration"]):
                continue
            title_score, artist_score, combined = result_match(item, meta)
            ranked.append(
                (
                    bool(item.get("syncedLyrics")),
                    combined,
                    title_score,
                    artist_score,
                    item,
                )
            )

        ranked.sort(key=lambda row: row[:4], reverse=True)
        language_consensus = candidate_language_consensus(data, meta)
        dbg(
            f"LRCLIB search {query!r}: {len(ranked)} usable candidates "
            f"language={language_consensus or 'unknown'}"
        )
        if best_timed and best_item is not None:
            best_rank = timed_result_rank(
                best_timed,
                best_item,
                meta,
                best_priority,
                language_consensus,
            )
        for (
            has_synced,
            _combined,
            _title_score,
            _artist_score,
            item,
        ) in ranked[:10]:
            source = f"lrclib:search:{item.get('id', 'unknown')}"
            if has_synced:
                result = lrclib_candidate(item, meta, source)
                if result and result["kind"] == "timed":
                    rank = timed_result_rank(
                        result, item, meta, 0.0, language_consensus
                    )
                    if best_rank is None or rank > best_rank:
                        best_timed = result
                        best_item = item
                        best_priority = 0.0
                        best_rank = rank
            elif plain_fallback is None:
                result = lrclib_candidate(item, meta, source)
                if result and result["kind"] == "plain":
                    plain_fallback = result

    if best_timed and not (exact_uncertain and best_priority == 1.0):
        dbg(
            "LRCLIB selected synced candidate: "
            f"{best_timed.get('source', 'unknown')}"
        )
        return best_timed, contacted
    if exact_uncertain or exact_language_blocked:
        dbg("LRCLIB withheld a language-uncertain exact candidate")
        # Do not negative-cache a candidate deliberately withheld for language.
        return None, False
    if plain_fallback:
        dbg("LRCLIB returned plain lyrics; waiting for synced fallbacks")
        return plain_fallback, contacted
    return None, contacted


def meting_candidate_score(item, meta):
    title_score, artist_score, combined = result_match(item, meta)
    duration = (
        parse_source_duration(item.get("duration"))
        if isinstance(item, dict)
        else 0.0
    )
    if not candidate_is_acceptable(item, meta):
        return None
    if not duration_matches(duration, meta["duration"]):
        return None
    return title_score, artist_score, combined, duration


def fetch_meting(server, meta):
    """Use Meting only as a fallback, trying several ranked song IDs."""
    contacted = False
    plain_fallback = None
    best_timed = None
    best_rank = None
    seen_ids = set()

    for query in generate_queries(meta)[:2]:
        data, responded = request_json(
            METING_URL,
            {
                "server": server,
                "type": "search",
                "id": "0",
                "keyword": query,
            },
        )
        contacted = contacted or responded
        if not isinstance(data, list):
            continue

        ranked = []
        for item in data:
            if not isinstance(item, dict):
                continue
            score = meting_candidate_score(item, meta)
            song_id = item.get("id")
            if score is None or song_id in (None, ""):
                continue
            ranked.append((score[2], score[0], score[1], item))
        ranked.sort(key=lambda row: row[:3], reverse=True)
        dbg(
            f"Meting/{server} search {query!r}: "
            f"{len(ranked)} usable candidates"
        )

        for _combined, _title_score, _artist_score, item in ranked[:5]:
            song_id = str(item.get("id"))
            if song_id in seen_ids:
                continue
            seen_ids.add(song_id)
            raw_lrc, responded = request_text(
                METING_URL,
                {"server": server, "type": "lrc", "id": song_id},
            )
            contacted = contacted or responded
            if not raw_lrc.strip():
                continue
            result = prepare_result(
                raw_lrc,
                meta,
                f"{server}:{song_id}",
                parse_source_duration(item.get("duration")),
            )
            if result and result["kind"] == "timed":
                rank = timed_result_rank(result, item, meta)
                if best_rank is None or rank > best_rank:
                    best_timed = result
                    best_rank = rank
            if result and result["kind"] == "plain" and plain_fallback is None:
                plain_fallback = result

    if best_timed:
        dbg(
            f"Meting/{server} selected synced candidate: "
            f"{best_timed.get('source', 'unknown')}"
        )
        return best_timed, contacted
    return plain_fallback, contacted


def fetch_online(meta):
    """Try all sources within one bounded network budget."""
    global request_deadline
    previous_deadline = request_deadline
    request_deadline = time.monotonic() + FETCH_DEADLINE
    try:
        contacted = False
        plain_fallback = None

        for fetcher in (
            fetch_lrclib,
            lambda current_meta: fetch_meting("netease", current_meta),
            lambda current_meta: fetch_meting("tencent", current_meta),
        ):
            result, responded = fetcher(meta)
            contacted = contacted or responded
            if result and result["kind"] == "timed":
                return result, contacted
            if result and plain_fallback is None:
                plain_fallback = result

        if plain_fallback:
            return plain_fallback, contacted
        return None, contacted
    finally:
        request_deadline = previous_deadline


@contextlib.contextmanager
def cache_lock(path):
    """Serialize duplicate Waybar instances fetching the same track."""
    lock_path = Path(f"{path}.lock")
    try:
        lock_path.parent.mkdir(parents=True, exist_ok=True)
        lock_file = lock_path.open("a+", encoding="utf-8")
    except OSError as error:
        # A read-only/broken cache must not prevent lyrics from working.
        dbg(f"cache lock unavailable: {error}")
        yield
        return

    try:
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        except OSError as error:
            dbg(f"cache lock unavailable: {error}")
        yield
    finally:
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
        except OSError:
            pass
        lock_file.close()


def cache_identity(meta):
    return json.dumps(
        {
            "track_id": meta.get("track_id", ""),
            "title": meta.get("title", ""),
            "artist": meta.get("artist_value", meta.get("artist", "")),
            "album": meta.get("album", ""),
            "duration_ms": round(float(meta.get("duration", 0.0)) * 1000),
        },
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )


def cache_path(meta):
    identity = cache_identity(meta)
    digest = hashlib.sha256(identity.encode("utf-8")).hexdigest()[:20]
    readable = re.sub(
        r"[^\w .-]+",
        "_",
        f"{meta.get('artist', 'unknown')} - {meta.get('title', 'unknown')}",
        flags=re.UNICODE,
    ).strip(" .")[:80]
    # Filename limits are byte-based; Japanese/emoji titles can use multiple
    # bytes per character, so leave ample room for the digest and extension.
    while len(readable.encode("utf-8")) > 120:
        readable = readable[:-1]
    readable = readable or "track"
    return CACHE_DIR / f"{readable}.{digest}.json"


def load_cache(path, meta):
    try:
        with path.open("r", encoding="utf-8") as cache_file:
            payload = json.load(cache_file)
    except (OSError, TypeError, ValueError):
        return None

    if not isinstance(payload, dict):
        return None
    if payload.get("version") != CACHE_VERSION:
        return None
    if payload.get("identity") != cache_identity(meta):
        return None

    try:
        age = max(0.0, time.time() - float(payload.get("fetched_at", 0)))
    except (TypeError, ValueError):
        return None

    kind = payload.get("kind")
    if kind == "none":
        if age > NEGATIVE_CACHE_TTL:
            return None
        return {"kind": "none", "source": payload.get("source", "cache")}
    if kind not in {"timed", "plain"}:
        return None
    max_age = PLAIN_CACHE_TTL if kind == "plain" else POSITIVE_CACHE_TTL
    if age > max_age:
        return None

    result = prepare_result(
        payload.get("lrc", ""),
        meta,
        payload.get("source", "cache"),
        payload.get("source_duration", 0.0),
    )
    if result and result["kind"] == kind:
        dbg(f"cache hit: {path.name}")
        return result
    return None


def write_atomic(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=str(path.parent)
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as temporary_file:
            json.dump(payload, temporary_file, ensure_ascii=False)
            temporary_file.write("\n")
            temporary_file.flush()
            os.fsync(temporary_file.fileno())
        os.replace(temporary_name, path)
    except Exception:
        try:
            os.unlink(temporary_name)
        except OSError:
            pass
        raise


def save_cache(path, meta, result, source_duration=0.0):
    payload = {
        "version": CACHE_VERSION,
        "fetched_at": time.time(),
        "identity": cache_identity(meta),
        "kind": result["kind"],
        "source": result.get("source", "unknown"),
        "language": result.get("language", "unknown"),
        "source_duration": parse_source_duration(source_duration),
        "lrc": result.get("raw", ""),
    }
    try:
        write_atomic(path, payload)
        dbg(f"cache write: {path.name}")
    except OSError as error:
        dbg(f"cache write failed: {error}")


def fetch_lyrics(meta):
    """Load a validated cache entry or fetch one while holding its lock."""
    path = cache_path(meta)
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
    except OSError as error:
        dbg(f"cache directory unavailable: {error}")

    with cache_lock(path):
        cached = load_cache(path, meta)
        if cached:
            return cached

        result, contacted = fetch_online(meta)
        if result:
            save_cache(path, meta, result)
            return result
        if contacted:
            none_result = {"kind": "none", "source": "providers"}
            save_cache(path, meta, none_result)
            return none_result

        # Do not turn a timeout/HTTP failure into a permanent "no lyrics"
        # result.  The foreground loop will retry this track later.
        return {"kind": "retry", "source": "network"}


# Shared state is protected because every Waybar output can have its own
# long-running module process and the network worker runs in another thread.
state_lock = threading.Lock()
current_track_key = None
lyrics_data = None


class FetchWorker:
    """Keep one latest-job worker; skipped tracks cannot spawn threads."""

    def __init__(self):
        self.jobs = queue.Queue(maxsize=1)
        self.jobs_lock = threading.Lock()
        self.thread = threading.Thread(target=self._run, daemon=True)
        self.thread.start()

    def request(self, meta, track_key):
        with self.jobs_lock:
            try:
                self.jobs.get_nowait()
                self.jobs.task_done()
            except queue.Empty:
                pass
            try:
                self.jobs.put_nowait((meta, track_key))
            except queue.Full:
                # The worker may have taken the item between get_nowait and
                # put_nowait; retain the newest request in that rare race.
                try:
                    self.jobs.get_nowait()
                    self.jobs.task_done()
                except queue.Empty:
                    pass
                try:
                    self.jobs.put_nowait((meta, track_key))
                except queue.Full:
                    pass

    def _run(self):
        global lyrics_data
        while True:
            meta, track_key = self.jobs.get()
            try:
                try:
                    result = fetch_lyrics(meta)
                except Exception as error:  # noqa: BLE001
                    # Keep the worker alive after an unexpected provider error.
                    dbg(f"background fetch failed: {error!r}")
                    result = {"kind": "retry", "source": "exception"}
                if not isinstance(result, dict):
                    result = {"kind": "retry", "source": "invalid-result"}
                if result.get("kind") == "retry":
                    result = dict(result)
                    result["retry_after"] = time.monotonic() + RETRY_INTERVAL

                with state_lock:
                    if track_key == current_track_key:
                        lyrics_data = result
                        dbg(
                            f"background result accepted: {track_key[:12]} "
                            f"kind={result.get('kind')}"
                        )
            finally:
                self.jobs.task_done()


def make_track_key(meta):
    return hashlib.sha256(cache_identity(meta).encode("utf-8")).hexdigest()


def read_visible():
    try:
        return STATE_FILE.read_text(encoding="utf-8").strip().lower() not in {
            "false",
            "0",
            "no",
            "off",
        }
    except OSError:
        return True


def get_position():
    value = run_playerctl(["position"], timeout=0.8)
    position = float(value)
    if not math.isfinite(position):
        raise ValueError(f"invalid player position: {value!r}")
    return max(0.0, position)


def line_at_position(result, position):
    index = bisect.bisect_right(result["timestamps"], position) - 1
    if index < 0:
        return ""
    return result["lines"][index][1]


def main():
    global current_track_key, lyrics_data

    worker = FetchWorker()
    last_output = None

    def emit(payload):
        nonlocal last_output
        serialized = json.dumps(payload, ensure_ascii=False)
        if serialized != last_output:
            print(serialized, flush=True)
            last_output = serialized

    while True:
        try:
            meta = get_metadata()
            if not meta or meta["status"] != "Playing":
                emit({"text": "", "class": "inactive"})
                time.sleep(INACTIVE_INTERVAL)
                continue

            track_key = make_track_key(meta)
            with state_lock:
                changed = track_key != current_track_key
                if changed:
                    current_track_key = track_key
                    lyrics_data = None

            if changed:
                dbg(
                    f"track changed: {meta['artist']} - {meta['title']} "
                    f"({meta['duration']:.3f}s)"
                )
                worker.request(meta, track_key)

            visible = read_visible()
            with state_lock:
                result = lyrics_data

            if result and result.get("kind") == "retry":
                if time.monotonic() >= result.get("retry_after", 0.0):
                    with state_lock:
                        if (
                            track_key == current_track_key
                            and lyrics_data is result
                        ):
                            lyrics_data = None
                    worker.request(meta, track_key)
                    result = None

            if not visible:
                emit({"text": "", "class": "hidden"})
            elif result is None:
                emit({"text": "", "class": "loading"})
            elif result.get("kind") == "timed":
                try:
                    position = get_position()
                    emit(
                        {
                            "text": line_at_position(result, position),
                            "class": "lyrics",
                            "tooltip": (
                                f"{meta['artist']} - {meta['title']}\n"
                                f"来源: {result.get('source', 'unknown')}"
                            ),
                        }
                    )
                except (
                    OSError,
                    subprocess.CalledProcessError,
                    subprocess.TimeoutExpired,
                    ValueError,
                ) as error:
                    dbg(f"position unavailable: {error}")
            elif result.get("kind") == "plain":
                emit(
                    {
                        "text": " 󰝚  ",
                        "class": "plain",
                        "tooltip": (
                            f"{meta['artist']} - {meta['title']}\n"
                            "仅找到未同步歌词"
                        ),
                    }
                )
            else:
                emit(
                    {
                        "text": " 󰝚  ",
                        "class": "none",
                        "tooltip": (
                            f"{meta['artist']} - {meta['title']}\n未找到歌词"
                        ),
                    }
                )

            time.sleep(POLL_INTERVAL)
        except KeyboardInterrupt:
            return
        except BrokenPipeError:
            return
        except Exception as error:  # noqa: BLE001 - keep Waybar alive
            dbg(f"main loop failed: {error!r}")
            emit({"text": "", "class": "error"})
            time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
