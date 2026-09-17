#!/usr/bin/env python3
"""Rasterize launcher, workspace/taskbar, and tray icons sharply on HiDPI outputs."""

from pathlib import Path


def replace(path: str, old: str, new: str, expected: int = 1) -> None:
    target = Path(path)
    text = target.read_text()
    count = text.count(old)
    if count != expected:
        raise SystemExit(f"icon raster source changed in {path}: expected {expected}, found {count}")
    target.write_text(text.replace(old, new))


replace(
    "src/shell/bar/widgets/taskbar_widget.cpp",
    "static_cast<int>(std::round(iconSize)), true",
    "static_cast<int>(std::ceil(iconSize * 2.0F)), false",
)
replace(
    "src/shell/launcher/launcher_panel.cpp",
    "m_iconTargetSize, true",
    "m_iconTargetSize, false",
    expected=4,
)
replace(
    "src/shell/bar/widgets/tray_widget.cpp",
    "iconRequestSize, true",
    "iconRequestSize, false",
    expected=2,
)
