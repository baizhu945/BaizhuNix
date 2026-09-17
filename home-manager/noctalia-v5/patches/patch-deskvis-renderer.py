#!/usr/bin/env python3
"""Add a per-desktop-visualizer native/V4 rendering profile."""

from pathlib import Path


def replace(path: str, old: str, new: str, label: str) -> None:
    target = Path(path)
    text = target.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match in {path}, found {count}")
    target.write_text(text.replace(old, new))


replace(
    "src/render/core/render_styles.h",
    """  bool reversed = false;
  bool centered = false;
};
""",
    """  bool reversed = false;
  bool centered = false;
  bool v4Style = false;
};
""",
    "DeskVis renderer style flag",
)
replace(
    "src/render/core/render_styles.h",
    """      && lhs.reversed == rhs.reversed
      && lhs.centered == rhs.centered;
""",
    """      && lhs.reversed == rhs.reversed
      && lhs.centered == rhs.centered
      && lhs.v4Style == rhs.v4Style;
""",
    "DeskVis renderer style equality",
)
replace(
    "src/render/programs/audio_spectrum_program.cpp",
    """  void pushQuad(std::vector<GLfloat>& out, float x0, float y0, float x1, float y1, const Color& color) {
    if (x1 <= x0 || y1 <= y0 || color.a <= 0.0F) {
      return;
    }
    pushVertex(out, x0, y0, color);
    pushVertex(out, x1, y0, color);
    pushVertex(out, x0, y1, color);
    pushVertex(out, x0, y1, color);
    pushVertex(out, x1, y0, color);
    pushVertex(out, x1, y1, color);
  }
""",
    """  void pushQuad(std::vector<GLfloat>& out, float x0, float y0, float x1, float y1, const Color& color) {
    if (x1 <= x0 || y1 <= y0 || color.a <= 0.0F) {
      return;
    }
    pushVertex(out, x0, y0, color);
    pushVertex(out, x1, y0, color);
    pushVertex(out, x0, y1, color);
    pushVertex(out, x0, y1, color);
    pushVertex(out, x1, y0, color);
    pushVertex(out, x1, y1, color);
  }

  void pushGradientQuad(
    std::vector<GLfloat>& out, float x0, float y0, float x1, float y1,
    const Color& freeEnd, const Color& anchoredEnd, bool horizontal
  ) {
    if (x1 <= x0 || y1 <= y0 || (freeEnd.a <= 0.0F && anchoredEnd.a <= 0.0F)) {
      return;
    }
    const Color& c00 = freeEnd;
    const Color& c10 = horizontal ? freeEnd : anchoredEnd;
    const Color& c01 = horizontal ? anchoredEnd : freeEnd;
    const Color& c11 = anchoredEnd;
    pushVertex(out, x0, y0, c00);
    pushVertex(out, x1, y0, c10);
    pushVertex(out, x0, y1, c01);
    pushVertex(out, x0, y1, c01);
    pushVertex(out, x1, y0, c10);
    pushVertex(out, x1, y1, c11);
  }
""",
    "DeskVis gradient quad helper",
)
replace(
    "src/render/programs/audio_spectrum_program.cpp",
    """  const int gapCount = std::max(0, barCount - 1);
  const float weightedSlots = static_cast<float>(barCount) + static_cast<float>(gapCount) * kGapToBarRatio;
""",
    """  const int gapCount = std::max(0, barCount - 1);
  const float gapToBarRatio = style.v4Style ? 0.4F : kGapToBarRatio;
  const float weightedSlots = static_cast<float>(barCount) + static_cast<float>(gapCount) * gapToBarRatio;
""",
    "DeskVis configurable bar gap ratio",
)
replace(
    "src/render/programs/audio_spectrum_program.cpp",
    """      : std::max(devicePixel, std::floor(barThickness * kGapToBarRatio * mainPixelScale) / mainPixelScale);
""",
    """      : std::max(devicePixel, std::floor(barThickness * gapToBarRatio * mainPixelScale) / mainPixelScale);
""",
    "DeskVis configurable gap thickness",
)
replace(
    "src/render/programs/audio_spectrum_program.cpp",
    """    float crossPixels = std::max(1.0F, std::floor(rawValue * crossAxisLen * crossPixelScale + 0.5F));
""",
    """    const float minimumCrossPixels = style.v4Style ? crossPixelScale : 1.0F;
    float crossPixels =
        std::max(minimumCrossPixels, std::floor(rawValue * crossAxisLen * crossPixelScale + 0.5F));
""",
    "DeskVis configurable minimum amplitude",
)
replace(
    "src/render/programs/audio_spectrum_program.cpp",
    """    const float t = barCount <= 1 ? 0.0F : static_cast<float>(i) / static_cast<float>(barCount - 1);
    const Color color = colorAt(style.color1, style.color2, t);

    if (horizontal) {
      pushQuad(m_vertices, mainStart, crossStart, mainEnd, crossEnd, color);
    } else {
      pushQuad(m_vertices, crossStart, mainStart, crossEnd, mainEnd, color);
    }
""",
    """    if (style.v4Style) {
      Color freeEnd = style.color2;
      freeEnd.a *= 0.75F;
      const Color anchoredEnd = style.color1;
      if (horizontal) {
        pushGradientQuad(m_vertices, mainStart, crossStart, mainEnd, crossEnd, freeEnd, anchoredEnd, true);
      } else {
        pushGradientQuad(m_vertices, crossStart, mainStart, crossEnd, mainEnd, freeEnd, anchoredEnd, false);
      }
    } else {
      const float t = barCount <= 1 ? 0.0F : static_cast<float>(i) / static_cast<float>(barCount - 1);
      const Color color = colorAt(style.color1, style.color2, t);
      if (horizontal) {
        pushQuad(m_vertices, mainStart, crossStart, mainEnd, crossEnd, color);
      } else {
        pushQuad(m_vertices, crossStart, mainStart, crossEnd, mainEnd, color);
      }
    }
""",
    "DeskVis configurable gradient behavior",
)
replace(
    "src/ui/visuals/audio_visualizer.h",
    """  void setCentered(bool centered);
  void setSmoothingTimeMs(float tauMs) noexcept { m_smoothingTauMs = std::max(0.0F, tauMs); }
""",
    """  void setCentered(bool centered);
  void setV4Style(bool enabled);
  void setSmoothingTimeMs(float tauMs) noexcept { m_smoothingTauMs = std::max(0.0F, tauMs); }
""",
    "DeskVis visualizer style API",
)
replace(
    "src/ui/visuals/audio_visualizer.cpp",
    """void AudioVisualizer::setCentered(bool centered) {
  auto next = style();
  next.centered = centered;
  setStyle(next);
}

void AudioVisualizer::syncPalette() {
""",
    """void AudioVisualizer::setCentered(bool centered) {
  auto next = style();
  next.centered = centered;
  setStyle(next);
}

void AudioVisualizer::setV4Style(bool enabled) {
  auto next = style();
  next.v4Style = enabled;
  setStyle(next);
}

void AudioVisualizer::syncPalette() {
""",
    "DeskVis visualizer style implementation",
)
replace(
    "src/shell/desktop/widgets/desktop_audio_visualizer_widget.h",
    """    bool showWhenIdle = true;
    ColorSpec color1 = colorSpecFromRole(ColorRole::Primary);
""",
    """    bool showWhenIdle = true;
    bool v4Profile = false;
    ColorSpec color1 = colorSpecFromRole(ColorRole::Primary);
""",
    "DeskVis profile option",
)
replace(
    "src/shell/desktop/widgets/desktop_audio_visualizer_widget.h",
    """  bool m_showWhenIdle = false;
  bool m_editorPreview = false;
""",
    """  bool m_showWhenIdle = false;
  bool m_v4Profile = false;
  bool m_editorPreview = false;
""",
    "DeskVis profile state",
)
replace(
    "src/shell/desktop/widgets/desktop_audio_visualizer_widget.cpp",
    """      m_reversed(options.reversed), m_centered(options.centered), m_showWhenIdle(options.showWhenIdle),
      m_color1(options.color1), m_color2(options.color2) {}
""",
    """      m_reversed(options.reversed), m_centered(options.centered), m_showWhenIdle(options.showWhenIdle),
      m_v4Profile(options.v4Profile), m_color1(options.color1), m_color2(options.color2) {}
""",
    "DeskVis profile constructor",
)
replace(
    "src/shell/desktop/widgets/desktop_audio_visualizer_widget.cpp",
    """  visualizer->setReversed(m_reversed);
  visualizer->setGradient(m_color1, m_color2);
""",
    """  visualizer->setReversed(m_reversed);
  visualizer->setV4Style(m_v4Profile);
  visualizer->setGradient(m_color1, m_color2);
""",
    "DeskVis initial renderer profile",
)
replace(
    "src/shell/desktop/widgets/desktop_audio_visualizer_widget.cpp",
    """  if (key == "show_when_idle") {
    if (const auto* v = std::get_if<bool>(&value)) {
      m_showWhenIdle = *v;
      return true;
    }
    return false;
  }
  return DesktopWidget::applySetting(key, value, allSettings, renderer);
""",
    """  if (key == "show_when_idle") {
    if (const auto* v = std::get_if<bool>(&value)) {
      m_showWhenIdle = *v;
      return true;
    }
    return false;
  }
  if (key == "visualizer_profile") {
    if (const auto* v = std::get_if<std::string>(&value)) {
      m_v4Profile = *v == "v4";
      m_visualizer->setV4Style(m_v4Profile);
      requestRedraw();
      return true;
    }
    return false;
  }
  return DesktopWidget::applySetting(key, value, allSettings, renderer);
""",
    "DeskVis live renderer profile",
)
replace(
    "src/shell/desktop/desktop_widget_factory.cpp",
    """            .showWhenIdle = getBoolSetting(settings, "show_when_idle", true),
            .color1 = getColorSpecSetting(settings, "color_1", colorSpecFromRole(ColorRole::Primary)),
""",
    """            .showWhenIdle = getBoolSetting(settings, "show_when_idle", true),
            .v4Profile = getStringSetting(settings, "visualizer_profile", "native") == "v4",
            .color1 = getColorSpecSetting(settings, "color_1", colorSpecFromRole(ColorRole::Primary)),
""",
    "DeskVis factory profile",
)
replace(
    "src/shell/desktop/desktop_widget_settings_registry.cpp",
    """    } else if (type == "audio_visualizer") {
      add(intSpec("bands", 32, 4.0, 128.0, 4.0));
""",
    """    } else if (type == "audio_visualizer") {
      add(segmentedSpec(
          "visualizer_profile", "native",
          {{"native", "desktop-widgets.editor.settings.visualizer-profile-native"},
           {"v4", "desktop-widgets.editor.settings.visualizer-profile-v4"}}
      ));
      add(intSpec("bands", 32, 4.0, 128.0, 4.0));
""",
    "DeskVis editor profile",
)

for locale, profile, native, v4 in (
    ("en", "Rendering Profile", "Native V5", "V4 / DeskVis"),
    ("zh-Hans", "渲染配置", "原生 V5", "V4 / DeskVis"),
):
    path = Path(f"assets/translations/{locale}.json")
    text = path.read_text()
    old = '        "visualization-mode": "' + ("Mode" if locale == "en" else "模式") + '",\n'
    new = (
        f'        "visualizer-profile": "{profile}",\n'
        f'        "visualizer-profile-native": "{native}",\n'
        f'        "visualizer-profile-v4": "{v4}",\n' + old
    )
    if text.count(old) != 1:
        raise SystemExit(f"DeskVis profile translation anchor changed in {locale}")
    path.write_text(text.replace(old, new))
