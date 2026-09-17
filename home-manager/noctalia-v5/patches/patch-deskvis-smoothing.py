#!/usr/bin/env python3
"""Select V4 attack/decay smoothing only for V4-profile visualizers."""

from pathlib import Path


def replace(path: str, old: str, new: str, label: str) -> None:
    target = Path(path)
    text = target.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match in {path}, found {count}")
    target.write_text(text.replace(old, new))


replace(
    "src/ui/visuals/audio_visualizer.h",
    """  void setV4Style(bool enabled);
  void setSmoothingTimeMs(float tauMs) noexcept { m_smoothingTauMs = std::max(0.0F, tauMs); }
""",
    """  void setV4Style(bool enabled);
  void setV4Smoothing(bool enabled) noexcept { m_v4Smoothing = enabled; }
  void setSmoothingTimeMs(float tauMs) noexcept { m_smoothingTauMs = std::max(0.0F, tauMs); }
""",
    "DeskVis smoothing profile API",
)
replace(
    "src/ui/visuals/audio_visualizer.h",
    """  float m_smoothingTauMs = 60.0F;
  bool m_converged = true;
""",
    """  float m_smoothingTauMs = 60.0F;
  bool m_v4Smoothing = false;
  bool m_converged = true;
""",
    "DeskVis smoothing profile state",
)
replace(
    "src/ui/visuals/audio_visualizer.cpp",
    """  const float alpha = m_smoothingTauMs > 0.0F ? 1.0F - std::exp(-std::max(0.0F, deltaMs) / m_smoothingTauMs) : 1.0F;
""",
    """  const float nativeAlpha =
      m_smoothingTauMs > 0.0F ? 1.0F - std::exp(-std::max(0.0F, deltaMs) / m_smoothingTauMs) : 1.0F;
""",
    "DeskVis native smoothing coefficient",
)
replace(
    "src/ui/visuals/audio_visualizer.cpp",
    """    display += delta * alpha;
    converged = false;
    changed = true;
""",
    """    float alpha = nativeAlpha;
    if (m_v4Smoothing) {
      constexpr float kFrameMs = 1000.0F / 60.0F;
      const float frameAlpha = delta > 0.0F ? 0.65F : 0.18F;
      alpha = 1.0F - std::pow(1.0F - frameAlpha, std::max(0.0F, deltaMs) / kFrameMs);
    }
    display += delta * alpha;
    converged = false;
    changed = true;
""",
    "DeskVis selectable smoothing algorithm",
)
replace(
    "src/shell/desktop/widgets/desktop_audio_visualizer_widget.cpp",
    """  visualizer->setV4Style(m_v4Profile);
  visualizer->setGradient(m_color1, m_color2);
""",
    """  visualizer->setV4Style(m_v4Profile);
  visualizer->setV4Smoothing(m_v4Profile);
  visualizer->setGradient(m_color1, m_color2);
""",
    "DeskVis initial smoothing profile",
)
replace(
    "src/shell/desktop/widgets/desktop_audio_visualizer_widget.cpp",
    """      m_visualizer->setV4Style(m_v4Profile);
      requestRedraw();
""",
    """      m_visualizer->setV4Style(m_v4Profile);
      m_visualizer->setV4Smoothing(m_v4Profile);
      requestRedraw();
""",
    "DeskVis live smoothing profile",
)
