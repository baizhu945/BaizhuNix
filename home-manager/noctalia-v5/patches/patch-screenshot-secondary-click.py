#!/usr/bin/env python3
"""Make the screenshot widget's secondary-click action configurable."""

from pathlib import Path


def replace(path: str, old: str, new: str, label: str) -> None:
    target = Path(path)
    text = target.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match in {path}, found {count}")
    target.write_text(text.replace(old, new))


replace(
    "src/shell/bar/widgets/screenshot_widget.h",
    """  enum class PrimaryClick : std::uint8_t {
    Region,
    Fullscreen,
  };

  struct Options {
    std::string glyph = "screenshot";
    std::string customImage;
    bool customImageColorize = false;
  };
""",
    """  enum class PrimaryClick : std::uint8_t {
    Region,
    Fullscreen,
  };

  enum class SecondaryClick : std::uint8_t {
    Menu,
    Fullscreen,
  };

  struct Options {
    std::string glyph = "screenshot";
    std::string customImage;
    bool customImageColorize = false;
    SecondaryClick secondaryClick = SecondaryClick::Menu;
  };
""",
    "screenshot secondary-click option",
)
replace(
    "src/shell/bar/widgets/screenshot_widget.h",
    """  std::string m_barPosition;
  WidgetCustomImage m_customImage;
""",
    """  std::string m_barPosition;
  SecondaryClick m_secondaryClick = SecondaryClick::Menu;
  WidgetCustomImage m_customImage;
""",
    "screenshot secondary-click state",
)
replace(
    "src/shell/bar/widgets/screenshot_widget.cpp",
    """      m_barPosition(std::move(barPosition)),
      m_customImage(widget_custom_image::fromConfig(options.customImage, options.customImageColorize)) {}
""",
    """      m_barPosition(std::move(barPosition)), m_secondaryClick(options.secondaryClick),
      m_customImage(widget_custom_image::fromConfig(options.customImage, options.customImageColorize)) {}
""",
    "screenshot secondary-click constructor",
)
replace(
    "src/shell/bar/widgets/screenshot_widget.cpp",
    """    if (!data.pressed && data.button == BTN_RIGHT) {
      openCaptureMenu();
    }
""",
    """    if (!data.pressed && data.button == BTN_RIGHT) {
      if (m_secondaryClick == SecondaryClick::Fullscreen) {
        m_screenshots.captureFullscreen(outputOptions());
      } else {
        openCaptureMenu();
      }
    }
""",
    "screenshot secondary-click behavior",
)
replace(
    "src/shell/bar/widgets/screenshot_widget_definition.cpp",
    """const noctalia::bar::WidgetDefinition<ScreenshotWidget::Options>& screenshotWidgetDefinition() {
  using Options = ScreenshotWidget::Options;

  static const noctalia::bar::WidgetDefinition<Options> definition{
      .type = "screenshot",
      .fields = noctalia::bar::glyphButtonFields<Options>(),
  };
""",
    """const noctalia::bar::WidgetDefinition<ScreenshotWidget::Options>& screenshotWidgetDefinition() {
  using noctalia::bar::field;
  using Options = ScreenshotWidget::Options;

  static const noctalia::bar::WidgetDefinition<Options> definition{
      .type = "screenshot",
      .fields = [] {
        auto fields = noctalia::bar::glyphButtonFields<Options>();
        fields.push_back(field<&Options::secondaryClick>({
            .key = "secondary_click",
            .choices = {
                {
                    .value = ScreenshotWidget::SecondaryClick::Menu,
                    .configValue = "menu",
                    .labelKey = "settings.widgets.options.menu",
                },
                {
                    .value = ScreenshotWidget::SecondaryClick::Fullscreen,
                    .configValue = "fullscreen",
                    .labelKey = "settings.widgets.options.fullscreen",
                },
            },
            .presentation = settings::WidgetSettingPresentation{.segmented = true},
        }));
        return fields;
      }(),
  };
""",
    "screenshot setting definition",
)

for locale, menu, fullscreen, label, description in (
    (
        "en",
        "Capture Menu",
        "Current Display",
        "Secondary Click",
        "Choose whether secondary click opens the capture menu or immediately captures the current display",
    ),
    (
        "zh-Hans",
        "截图菜单",
        "当前显示器",
        "右键操作",
        "选择右键打开截图菜单，或立即截取当前显示器",
    ),
):
    path = Path(f"assets/translations/{locale}.json")
    text = path.read_text()
    options_old = '        "megabytes": "MB/s",\n'
    options_new = options_old + f'        "menu": "{menu}",\n        "fullscreen": "{fullscreen}",\n'
    if text.count(options_old) != 1:
        raise SystemExit(f"screenshot option translation anchor changed in {locale}")
    text = text.replace(options_old, options_new)
    settings_old = '        "show-label": {\n'
    settings_new = (
        f'        "secondary-click": {{\n'
        f'          "description": "{description}",\n'
        f'          "label": "{label}"\n'
        f'        }},\n' + settings_old
    )
    if text.count(settings_old) != 1:
        raise SystemExit(f"screenshot setting translation anchor changed in {locale}")
    path.write_text(text.replace(settings_old, settings_new))
