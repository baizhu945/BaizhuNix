#!/usr/bin/env python3
"""Expose compositor blur for panels as a live configuration option."""

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
    """  struct PanelConfig {
    PanelTransparencyMode transparencyMode = PanelTransparencyMode::Solid;
    bool borders = true;                   // outline on floating panel surfaces
""",
    """  struct PanelConfig {
    PanelTransparencyMode transparencyMode = PanelTransparencyMode::Solid;
    bool compositorBlurEnabled = true;     // submit rounded panel blur regions to the compositor
    bool borders = true;                   // outline on floating panel surfaces
""",
    "panel compositor blur config type",
)
replace(
    "src/config/schema/config_schema.cpp",
    """          enumField(&ShellConfig::PanelConfig::transparencyMode, "transparency_mode", kPanelTransparencyModes),
          field(&ShellConfig::PanelConfig::borders, "borders"),
""",
    """          enumField(&ShellConfig::PanelConfig::transparencyMode, "transparency_mode", kPanelTransparencyModes),
          field(&ShellConfig::PanelConfig::compositorBlurEnabled, "compositor_blur_enabled"),
          field(&ShellConfig::PanelConfig::borders, "borders"),
""",
    "panel compositor blur schema",
)
replace(
    "src/shell/panel/panel_manager.cpp",
    """  if (m_surface == nullptr || m_activePanel == nullptr) {
    return;
  }

  if (blurTraceEnabled()) {""",
    """  if (m_surface == nullptr || m_activePanel == nullptr) {
    return;
  }
  if (m_config != nullptr && !m_config->config().shell.panel.compositorBlurEnabled) {
    m_surface->clearBlurRegion();
    return;
  }

  if (blurTraceEnabled()) {""",
    "panel compositor blur behavior",
)
replace(
    "src/shell/settings/settings_registry.cpp",
    """    entries.push_back(makeEntry(
        SettingsSection::Panels, "effects", tr("settings.schema.panels.borders.label"),
        tr("settings.schema.panels.borders.description"), {"shell", "panel", "borders"},
        ToggleSetting{cfg.shell.panel.borders}, "outline border shell edge"
    ));
""",
    """    entries.push_back(makeEntry(
        SettingsSection::Panels, "effects", tr("settings.schema.panels.compositor-blur.label"),
        tr("settings.schema.panels.compositor-blur.description"),
        {"shell", "panel", "compositor_blur_enabled"}, ToggleSetting{cfg.shell.panel.compositorBlurEnabled},
        "compositor background blur glass protocol"
    ));
    entries.push_back(makeEntry(
        SettingsSection::Panels, "effects", tr("settings.schema.panels.borders.label"),
        tr("settings.schema.panels.borders.description"), {"shell", "panel", "borders"},
        ToggleSetting{cfg.shell.panel.borders}, "outline border shell edge"
    ));
""",
    "panel compositor blur settings entry",
)

for locale, label, description in (
    (
        "en",
        "Compositor Blur",
        "Allow the compositor to blur the background behind attached and floating panels",
    ),
    (
        "zh-Hans",
        "合成器模糊",
        "允许合成器模糊附着面板和悬浮面板后方的背景",
    ),
):
    path = Path(f"assets/translations/{locale}.json")
    text = path.read_text()
    old = '        "control-center-sidebar": {\n'
    new = (
        f'        "compositor-blur": {{\n'
        f'          "description": "{description}",\n'
        f'          "label": "{label}"\n'
        f'        }},\n' + old
    )
    if text.count(old) != 1:
        raise SystemExit(f"panel blur translation anchor changed in {locale}")
    path.write_text(text.replace(old, new))
