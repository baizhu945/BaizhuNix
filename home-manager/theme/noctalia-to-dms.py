import json
import re
import sys
import os

#  颜色工具 ────────────────────────────────────────────────────────────


def h2r(h):
    """hex → (r, g, b)"""
    h = h.lstrip("#")
    return int(h[:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def r2h(r, g, b):
    """(r, g, b) → hex"""
    return f"#{round(r):02x}{round(g):02x}{round(b):02x}"


def blend(c1, c2, t):
    """线性插值：t=0 → c1，t=1 → c2"""
    r1, g1, b1 = h2r(c1)
    r2, g2, b2 = h2r(c2)
    return r2h(r1+(r2-r1)*t, g1+(g2-g1)*t, b1+(b2-b1)*t)


def luminance(h):
    """WCAG 相对亮度，用于判断深/浅色主题"""
    def lin(c): return c/12.92 if c <= 0.04045 else ((c+0.055)/1.055)**2.4
    r, g, b = (c/255 for c in h2r(h))
    return 0.2126*lin(r) + 0.7152*lin(g) + 0.0722*lin(b)

#  同步 waybar colors.css ───────────────────────────────────────────────


def update_waybar_lyrics_color(hex_color, css_path=None):
    """更新（或创建）~/.config/waybar/colors.css 中 @define-color lyrics 这一行，
    只替换 rgba() 里的 r, g, b 三个分量，最后一位透明度保持原样不动。
    若文件中尚无该定义，则新增一行，透明度默认取 0.8。"""
    if css_path is None:
        css_path = os.path.expanduser("~/.config/waybar/colors.css")

    r, g, b = (round(v) for v in h2r(hex_color))

    pattern = re.compile(
        r"(@define-color\s+lyrics\s+rgba\(\s*)"
        r"\d+\s*,\s*\d+\s*,\s*\d+"
        r"(\s*,\s*[\d.]+\s*\)\s*;)"
    )

    content = ""
    if os.path.exists(css_path):
        with open(css_path) as f:
            content = f.read()

    if pattern.search(content):
        content = pattern.sub(rf"\g<1>{r}, {g}, {b}\g<2>", content)
    else:
        if content and not content.endswith("\n"):
            content += "\n"
        content += f"@define-color lyrics     rgba({r}, {g}, {b}, 0.9);\n"

    os.makedirs(os.path.dirname(css_path), exist_ok=True)
    with open(css_path, "w") as f:
        f.write(content)

    print(f"[noctalia-to-dms] 已同步 lyrics 颜色 → {css_path}")

#  读取 noctalia 颜色文件 ───────────────────────────────────────────────


src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    c = json.load(f)

# 直接命名映射（noctalia mXxx → 去掉 "m" 前缀的 DMS 字段）
primary = c["mPrimary"]
on_primary = c["mOnPrimary"]
secondary = c["mSecondary"]
surface = c["mSurface"]
on_surface = c["mOnSurface"]
surf_var = c["mSurfaceVariant"]
on_sv = c["mOnSurfaceVariant"]
outline = c["mOutline"]
tertiary = c["mTertiary"]   # → warning
error = c["mError"]

#  推导 DMS 需要但 noctalia 没有的字段 ─────────────────────────────────

# 深色/浅色检测：亮度 < 0.18（约 18%）视为深色主题
is_dark = luminance(surface) < 0.18
target = "#ffffff" if is_dark else "#000000"

# primaryContainer：主色与表面色深度混合（深色主题呈暗调主色块）
# 65% 表面 + 35% 主色，保留色相但大幅压暗，视觉上类似 catppuccin 的效果
primary_ctn = blend(primary, surface, 0.65)

# surfaceContainer 三级：从表面向白/黑方向阶梯推移，模拟 Material 3 海拔层级
surf_ctn = blend(surface, target, 0.06)   # 轻微抬起（卡片底层）
surf_ctn_h = blend(surface, target, 0.13)   # 中等抬起（弹出层）
surf_ctn_hst = blend(surface, target, 0.22)   # 最高层（浮动组件）

# surfaceTint：主色以 8% 的极淡强度叠入表面色（悬停、选中的细节色差）
surface_tint = blend(surface, primary, 0.08)

#  组装扁平色板（dark 和 light 用同一套 noctalia 颜色）─────────────────
# noctalia 提取一套 palette，深浅模式用同一组颜色是合理的：
# 深色壁纸提取出的 mSurface 本来就是深色，浅色壁纸反之。

palette = {
    "primary":                 primary,
    "primaryText":             on_primary,
    "primaryContainer":        primary_ctn,
    "secondary":               secondary,
    "surface":                 surface,
    "surfaceText":             on_surface,
    "surfaceVariant":          surf_var,
    "surfaceVariantText":      on_sv,
    "surfaceTint":             surface_tint,
    "background":              surface,        # DMS background ≈ M3 surface
    "backgroundText":          on_surface,
    "outline":                 outline,
    "surfaceContainer":        surf_ctn,
    "surfaceContainerHigh":    surf_ctn_h,
    "surfaceContainerHighest": surf_ctn_hst,
    "error":                   error,
    "warning":                 tertiary,       # M3 tertiary 色调最接近 warning
    "info":                    secondary,      # M3 secondary 用作 info（偏蓝绿色）
}

theme = {
    "dark":  {"name": "Noctalia Wallpaper", **palette},
    "light": {"name": "Noctalia Wallpaper", **palette},
}

os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(dst, "w") as f:
    json.dump(theme, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"[noctalia-to-dms] 写入完成 → {dst}")

# 顺手把 noctalia 主色同步进 waybar 的 colors.css（lyrics 模块用）
update_waybar_lyrics_color(primary)
