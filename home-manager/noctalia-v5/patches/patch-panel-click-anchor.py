#!/usr/bin/env python3
"""Anchor every attached panel below the widget that opened it."""

from pathlib import Path

path = Path("src/shell/panel/panel_manager.cpp")
text = path.read_text()
old = """    const bool useAnchorForAttached =
        request.hasAnchorPosition && openNearClickEnabled(m_activePanel, m_activePanelId, m_config);"""
new = "    const bool useAnchorForAttached = request.hasAnchorPosition;"
if text.count(old) != 1:
    raise SystemExit("attached panel anchor source changed upstream")
path.write_text(text.replace(old, new))
