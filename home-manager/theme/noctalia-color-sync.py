import json
import os
import re
import sys


def hex_to_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def update_waybar_lyrics_color(hex_color, css_path=None):
    if css_path is None:
        css_path = os.path.expanduser("~/.config/waybar/colors.css")

    red, green, blue = hex_to_rgb(hex_color)
    pattern = re.compile(
        r"(@define-color\s+lyrics\s+rgba\(\s*)"
        r"\d+\s*,\s*\d+\s*,\s*\d+"
        r"(\s*,\s*[\d.]+\s*\)\s*;)"
    )

    content = ""
    if os.path.exists(css_path):
        with open(css_path, encoding="utf-8") as handle:
            content = handle.read()

    if pattern.search(content):
        content = pattern.sub(rf"\g<1>{red}, {green}, {blue}\g<2>", content)
    else:
        if content and not content.endswith("\n"):
            content += "\n"
        content += f"@define-color lyrics     rgba({red}, {green}, {blue}, 0.9);\n"

    os.makedirs(os.path.dirname(css_path), exist_ok=True)
    with open(css_path, "w", encoding="utf-8") as handle:
        handle.write(content)

    print(f"[noctalia-color-sync] 已同步歌词颜色 → {css_path}")


with open(sys.argv[1], encoding="utf-8") as handle:
    colors = json.load(handle)

update_waybar_lyrics_color(colors["mPrimary"])
