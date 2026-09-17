#!/usr/bin/env python3
"""Expose the OSD auto-hide delay as live configuration."""

from pathlib import Path


def replace(path: str, old: str, new: str, label: str) -> None:
    target = Path(path)
    text = target.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match in {path}, found {count}")
    target.write_text(text.replace(old, new))


replace(
    "src/config/config_types.h",
    """  float backgroundOpacity = 0.97F;
  bool border = true; // outline around OSD popup cards
""",
    """  float backgroundOpacity = 0.97F;
  int hideDelayMs = 1400;
  bool border = true; // outline around OSD popup cards
""",
    "OSD hide-delay config field",
)
replace(
    "src/config/schema/config_schema.cpp",
    """        field(&OsdConfig::backgroundOpacity, "background_opacity", kUnitRange),
        field(&OsdConfig::border, "border"),
""",
    """        field(&OsdConfig::backgroundOpacity, "background_opacity", kUnitRange),
        field(&OsdConfig::hideDelayMs, "hide_delay_ms", Range<std::int64_t>{250, 10000}),
        field(&OsdConfig::border, "border"),
""",
    "OSD hide-delay schema",
)
replace(
    "src/shell/osd/osd_overlay.cpp",
    """  constexpr int kHideDelayMs = Style::animSlow * 3 + Style::animFast * 2;

  enum class OsdRevealDir { FromLeft, FromRight, FromTop, FromBottom };
""",
    """  int osdHideDelayMs(const ConfigService* config) {
    return config != nullptr ? std::clamp(config->config().osd.hideDelayMs, 250, 10000)
                             : Style::animSlow * 3 + Style::animFast * 2;
  }

  enum class OsdRevealDir { FromLeft, FromRight, FromTop, FromBottom };
""",
    "OSD hide-delay runtime accessor",
)
replace(
    "src/shell/osd/osd_overlay.cpp",
    """      1.0F, 0.0F, kHideDelayMs, Easing::Linear, [](float /*v*/) {},
""",
    """      1.0F, 0.0F, static_cast<float>(osdHideDelayMs(m_config)), Easing::Linear, [](float /*v*/) {},
""",
    "OSD configured hide delay",
)
replace(
    "src/shell/settings/settings_registry.cpp",
    """    entries.push_back(makeEntry(
        SettingsSection::Osd, "osd", tr("settings.schema.shell.osd-offset-x.label"),
""",
    """    entries.push_back(makeEntry(
        SettingsSection::Osd, "osd", tr("settings.schema.shell.osd-hide-delay.label"),
        tr("settings.schema.shell.osd-hide-delay.description"), {"osd", "hide_delay_ms"},
        StepperSetting{.value = cfg.osd.hideDelayMs, .minValue = 250, .maxValue = 10000, .step = 100,
                       .valueSuffix = "ms"},
        "hud overlay timeout duration auto hide"
    ));
    entries.push_back(makeEntry(
        SettingsSection::Osd, "osd", tr("settings.schema.shell.osd-offset-x.label"),
""",
    "OSD hide-delay settings entry",
)

for locale, label, description in (
    ("en", "Auto-Hide Delay", "Time before an OSD popup starts hiding"),
    ("zh-Hans", "自动隐藏延迟", "OSD 弹窗开始隐藏前的等待时间"),
):
    path = Path(f"assets/translations/{locale}.json")
    text = path.read_text()
    old = '        "osd-offset-x": {\n'
    new = (
        f'        "osd-hide-delay": {{\n'
        f'          "description": "{description}",\n'
        f'          "label": "{label}"\n'
        f'        }},\n' + old
    )
    if text.count(old) != 1:
        raise SystemExit(f"OSD timeout translation anchor changed in {locale}")
    path.write_text(text.replace(old, new))
