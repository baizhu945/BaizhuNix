#!/usr/bin/env python3
"""Make the brightness widget's unavailable-output fallback configurable."""

from pathlib import Path


def replace(path: str, old: str, new: str, label: str) -> None:
    target = Path(path)
    text = target.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match in {path}, found {count}")
    target.write_text(text.replace(old, new))


replace(
    "src/shell/bar/widgets/brightness_widget.h",
    """  struct Options {
    bool showLabel = true;
  };
""",
    """  struct Options {
    bool showLabel = true;
    bool showWhenUnavailable = false;
  };
""",
    "brightness fallback option",
)
replace(
    "src/shell/bar/widgets/brightness_widget.h",
    """  bool m_showLabel = true;
  Glyph* m_glyph = nullptr;
""",
    """  bool m_showLabel = true;
  bool m_showWhenUnavailable = false;
  Glyph* m_glyph = nullptr;
""",
    "brightness fallback state",
)
replace(
    "src/shell/bar/widgets/brightness_widget.cpp",
    """BrightnessWidget::BrightnessWidget(BrightnessService* brightness, wl_output* output, Options options)
    : m_brightness(brightness), m_output(output), m_showLabel(options.showLabel) {}
""",
    """BrightnessWidget::BrightnessWidget(BrightnessService* brightness, wl_output* output, Options options)
    : m_brightness(brightness), m_output(output), m_showLabel(options.showLabel),
      m_showWhenUnavailable(options.showWhenUnavailable) {}
""",
    "brightness fallback constructor",
)
replace(
    "src/shell/bar/widgets/brightness_widget.cpp",
    """void BrightnessWidget::syncState(Renderer& renderer) {
  if (m_brightness == nullptr || m_glyph == nullptr || m_label == nullptr) {
    return;
  }

  auto* rootNode = root();
  const auto* display = m_brightness->findByOutput(m_output);
  if (display == nullptr) {
    m_lastAvailable = false;
    m_lastBrightness = -1.0F;
    if (rootNode != nullptr) {
      rootNode->setVisible(false);
      rootNode->setParticipatesInLayout(false);
    }
    return;
  }
""",
    """void BrightnessWidget::syncState(Renderer& renderer) {
  if (m_glyph == nullptr || m_label == nullptr) {
    return;
  }

  auto* rootNode = root();
  const auto* display = m_brightness != nullptr ? m_brightness->findByOutput(m_output) : nullptr;
  if (display == nullptr) {
    m_lastAvailable = false;
    m_lastBrightness = -1.0F;
    if (rootNode != nullptr) {
      rootNode->setVisible(m_showWhenUnavailable);
      rootNode->setParticipatesInLayout(m_showWhenUnavailable);
      static_cast<InputArea*>(rootNode)->clearTooltip();
    }
    if (!m_showWhenUnavailable) {
      return;
    }
    m_glyph->setGlyph("brightness-high");
    m_glyph->setGlyphSize(Style::baseGlyphSize * m_contentScale);
    m_glyph->setColor(widgetIconColorOr(colorSpecFromRole(ColorRole::OnSurface)));
    m_glyph->measure(renderer);
    m_label->setVisible(false);
    requestRedraw();
    return;
  }
""",
    "brightness fallback behavior",
)
replace(
    "src/shell/bar/widgets/brightness_widget_definition.cpp",
    """          field<&Options::showLabel>({
              .key = "show_label",
          }),
""",
    """          field<&Options::showLabel>({
              .key = "show_label",
          }),
          field<&Options::showWhenUnavailable>({
              .key = "show_when_unavailable",
          }),
""",
    "brightness fallback setting definition",
)

for locale, label, description in (
    (
        "en",
        "Show When Unavailable",
        "Keep the widget visible on outputs that do not provide brightness control",
    ),
    (
        "zh-Hans",
        "不可用时仍显示",
        "在不提供亮度控制的输出上仍然显示此小组件",
    ),
):
    path = Path(f"assets/translations/{locale}.json")
    text = path.read_text()
    old = '        "show-label": {\n'
    new = (
        f'        "show-when-unavailable": {{\n'
        f'          "description": "{description}",\n'
        f'          "label": "{label}"\n'
        f'        }},\n' + old
    )
    if text.count(old) != 1:
        raise SystemExit(f"brightness setting translation anchor changed in {locale}")
    path.write_text(text.replace(old, new))
