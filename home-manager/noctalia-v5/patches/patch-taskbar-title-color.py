#!/usr/bin/env python3
"""Make flat taskbar window-title labels honor the widget foreground color."""

from pathlib import Path

path = Path("src/shell/bar/widgets/taskbar_widget.cpp")
text = path.read_text()
old = '''          .fontWeight = fontWeight,
          .fontFamily = fontFamily,
          .maxWidth = windowTitleWidth,
'''
new = '''          .fontWeight = fontWeight,
          .fontFamily = fontFamily,
          .color = widgetForegroundOr(colorSpecFromRole(ColorRole::OnSurface)),
          .maxWidth = windowTitleWidth,
'''
if text.count(old) != 1:
    raise SystemExit(f"expected one taskbar title label initializer, found {text.count(old)}")
path.write_text(text.replace(old, new))
