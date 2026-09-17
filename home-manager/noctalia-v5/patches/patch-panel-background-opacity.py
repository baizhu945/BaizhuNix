#!/usr/bin/env python3
"""Use the configured panel opacity instead of inheriting transparent bar opacity."""

from pathlib import Path

path = Path("src/shell/panel/panel_manager.cpp")
text = path.read_text()
replacements = (
    (
        """    m_attachedBackgroundOpacity = m_activePanel->inheritsBarBackgroundOpacity()
        ? barConfig.backgroundOpacity
        : m_activePanel->attachedBackgroundOpacityOverride();""",
        "    m_attachedBackgroundOpacity = shell::panel_surface::backgroundOpacity(m_config);",
        "attached panel opacity",
    ),
    (
        "const float newOpacity = barConfig.backgroundOpacity;",
        "const float newOpacity = shell::panel_surface::backgroundOpacity(m_config);",
        "attached panel reload opacity",
    ),
)
for old, new, label in replacements:
    if text.count(old) != 1:
        raise SystemExit(f"{label} source changed upstream")
    text = text.replace(old, new)
path.write_text(text)
