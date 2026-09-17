#!/usr/bin/env python3
"""Select the V4 idle-fade duration only for V4-profile visualizers."""

from pathlib import Path

path = Path("src/shell/desktop/widgets/desktop_audio_visualizer_widget.cpp")
text = path.read_text()
old = "root()->opacity(), targetOpacity, Style::animNormal, Easing::EaseOutCubic,"
new = "root()->opacity(), targetOpacity, m_v4Profile ? 600 : Style::animNormal, Easing::EaseOutCubic,"
if text.count(old) != 1:
    raise SystemExit("DeskVis idle fade source changed upstream")
path.write_text(text.replace(old, new))
