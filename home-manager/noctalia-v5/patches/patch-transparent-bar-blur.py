#!/usr/bin/env python3
"""Do not request compositor blur for a fully transparent bar."""

from pathlib import Path

path = Path("src/shell/bar/bar.cpp")
text = path.read_text()
old = "if (!barContentVisuallyShown(instance)) {"
new = "if (!barContentVisuallyShown(instance) || instance.barConfig.backgroundOpacity <= 0.0F) {"
if text.count(old) != 1:
    raise SystemExit("transparent bar blur source changed upstream")
path.write_text(text.replace(old, new))
