#!/usr/bin/env python3
"""Keep attached and persistent panels from prewarming compositor blur."""

from pathlib import Path

paths = (
    Path("src/shell/panel/panel_manager.cpp"),
    Path("src/shell/panel/persistent_panel_host.cpp"),
)
old = ".prewarmBlur = true,"
new = ".prewarmBlur = false,"
counts = tuple(path.read_text().count(old) for path in paths)
if counts != (2, 1):
    raise SystemExit(f"panel prewarm blur source changed upstream: found {counts}")
for path in paths:
    text = path.read_text()
    path.write_text(text.replace(old, new))
