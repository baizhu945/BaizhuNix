{ config, lib, pkgs, ... }:

let
  playerctl-bin = "${pkgs.playerctl}/bin/playerctl";

  lyrics-script = pkgs.writers.writePython3Bin "waybar-lyrics" {
    libraries = with pkgs.python3Packages; [ requests ];
  } ''
    import sys
    import time
    import subprocess
    import requests
    import json
    import os
    import re


    STATE_FILE = "/tmp/waybar_lyrics_show"
    P = "${playerctl-bin}"


    def clean_text(text):
        if not text:
            return ""
        text = re.sub(r'\(feat\..*?\)', "", text, flags=re.IGNORECASE)
        text = re.sub(r'\(with.*?\)', "", text, flags=re.IGNORECASE)
        text = re.sub(r'\(.*?\)|\[.*?\]', "", text)
        text = re.sub(r'- .*Remaster.*', "", text, flags=re.IGNORECASE)
        text = re.sub(r' - Single| - Deluxe Edition', "", text)
        return text.strip()


    def get_metadata():
        try:
            cmd = [
                P, "-p", "spotify", "metadata",
                "--format", "{{title}}||{{artist}}||{{mpris:length}}"
            ]
            out = subprocess.check_output(cmd, text=True).strip()
            parts = out.split("||")
            if len(parts) < 3:
                return None
            return {
                "title": parts[0].strip(),
                "artist": parts[1].split(",")[0].strip(),
                "duration": int(parts[2]) // 1000000
            }
        except Exception:
            return None


    def fetch_lyrics(meta):
        base = "https://lrclib.net/api"
        try:
            p = {
                "track_name": meta["title"],
                "artist_name": meta["artist"],
                "duration": meta["duration"]
            }
            r = requests.get(f"{base}/get", params=p, timeout=3)
            if r.status_code == 200:
                return r.json().get("syncedLyrics", "")
        except Exception:
            pass
        try:
            q = f"{clean_text(meta['title'])} {meta['artist']}"
            r = requests.get(f"{base}/search", params={"q": q}, timeout=3)
            if r.status_code == 200 and r.json():
                return r.json()[0].get("syncedLyrics", "")
        except Exception:
            pass
        return ""


    def parse_lrc(lrc):
        lines = []
        for line in lrc.splitlines():
            m = re.match(r"\[(\d+):(\d+\.\d+)\](.*)", line)
            if m:
                sec = int(m.group(1)) * 60 + float(m.group(2))
                lines.append((sec, m.group(3).strip()))
        return lines


    if not os.path.exists(STATE_FILE):
        with open(STATE_FILE, "w") as f:
            f.write("true")

    last_id, lyrics_data = "", []

    while True:
        try:
            with open(STATE_FILE, "r") as f:
                visible = f.read().strip() == "true"
            status = subprocess.check_output(
                [P, "-p", "spotify", "status"], text=True
            ).strip()
        except Exception:
            status, visible = "Stopped", True

        meta = get_metadata()
        if status != "Playing" or not meta:
            print(json.dumps({"text": "", "class": "none"}))
            sys.stdout.flush()
            time.sleep(1.5)
            continue

        curr_id = f"{meta['title']}{meta['artist']}"
        if curr_id != last_id:
            lyrics_data = parse_lrc(fetch_lyrics(meta))
            last_id = curr_id

        if not visible or not lyrics_data:
            print(json.dumps({"text": ""}))
        else:
            try:
                pos = float(subprocess.check_output(
                    [P, "-p", "spotify", "position"], text=True
                ))
                curr_txt = ""
                for ts, txt in lyrics_data:
                    if pos >= ts:
                        curr_txt = txt
                    else:
                        break
                print(json.dumps({"text": curr_txt}, ensure_ascii=False))
            except Exception:
                print(json.dumps({"text": ""}))

        sys.stdout.flush()
        time.sleep(0.2)
  '';

  toggle-script = pkgs.writeShellScriptBin "lyrics-toggle" ''
    STATE_FILE="/tmp/waybar_lyrics_show"
    touch "$STATE_FILE"
    [ "$(cat $STATE_FILE)" = "true" ] && echo "false" > "$STATE_FILE" || echo "true" > "$STATE_FILE"
    pkill -RTMIN+8 waybar || true
  '';

in
{
  home.packages = [ pkgs.playerctl lyrics-script toggle-script ];
}

