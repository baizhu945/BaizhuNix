#!/usr/bin/env python3
"""Make QS_ICON_THEME precedence an explicit, live theme configuration choice."""

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
    """struct ThemeConfig {
""",
    """enum class IconThemeSource : std::uint8_t {
  System = 0,
  QsEnvironment = 1,
};

constexpr EnumOption<IconThemeSource> kIconThemeSources[] = {
    {IconThemeSource::System, "system", "settings.options.theme.icon-theme-source.system"},
    {IconThemeSource::QsEnvironment, "qs_environment", "settings.options.theme.icon-theme-source.qs-environment"},
};

struct ThemeConfig {
""",
    "icon theme source enum",
)
replace(
    "src/config/config_types.h",
    """  ShellThemeMode shellMode = ShellThemeMode::Follow;
  bool pureBlackDark = false;
""",
    """  ShellThemeMode shellMode = ShellThemeMode::Follow;
  IconThemeSource iconThemeSource = IconThemeSource::System;
  bool pureBlackDark = false;
""",
    "icon theme source config field",
)
replace(
    "src/config/schema/config_schema.cpp",
    """        enumField(&ThemeConfig::shellMode, "shell_mode", kShellThemeModes),
        field(&ThemeConfig::pureBlackDark, "pure_black_dark"),
""",
    """        enumField(&ThemeConfig::shellMode, "shell_mode", kShellThemeModes),
        enumField(&ThemeConfig::iconThemeSource, "icon_theme_source", kIconThemeSources),
        field(&ThemeConfig::pureBlackDark, "pure_black_dark"),
""",
    "icon theme source schema",
)
replace(
    "src/system/icon_resolver.h",
    """  static bool checkThemeChanged();
  static std::uint64_t themeGeneration();
""",
    """  static bool setPreferQsEnvironment(bool enabled);
  static bool checkThemeChanged();
  static std::uint64_t themeGeneration();
""",
    "icon theme source API",
)
replace(
    "src/system/icon_resolver.cpp",
    """    bool initialized = false;
    std::uint64_t generation = 1;
""",
    """    bool initialized = false;
    bool preferQsEnvironment = false;
    std::uint64_t generation = 1;
""",
    "icon theme source state",
)
replace(
    "src/system/icon_resolver.cpp",
    """  std::vector<std::string> readGtkThemeCandidates() {
    std::vector<std::string> candidates;

    if (auto value = readGSettingsIconTheme(); value.has_value()) {
""",
    """  std::vector<std::string> readGtkThemeCandidates(bool preferQsEnvironment) {
    std::vector<std::string> candidates;

    if (preferQsEnvironment) {
      if (const char* overrideTheme = std::getenv("QS_ICON_THEME"); overrideTheme != nullptr) {
        const std::string theme = trimAndUnquote(overrideTheme);
        if (!theme.empty()) {
          candidates.emplace_back(theme);
        }
      }
    }

    if (auto value = readGSettingsIconTheme(); value.has_value()) {
""",
    "icon theme candidate selection",
)
replace(
    "src/system/icon_resolver.cpp",
    """  IconThemePlan buildThemePlan() {
""",
    """  IconThemePlan buildThemePlan(bool preferQsEnvironment) {
""",
    "icon theme plan signature",
)
replace(
    "src/system/icon_resolver.cpp",
    """    for (const auto& candidate : readGtkThemeCandidates()) {
""",
    """    for (const auto& candidate : readGtkThemeCandidates(preferQsEnvironment)) {
""",
    "icon theme plan candidates",
)
replace(
    "src/system/icon_resolver.cpp",
    """      state.plan = buildThemePlan();
      state.initialized = true;
""",
    """      state.plan = buildThemePlan(state.preferQsEnvironment);
      state.initialized = true;
""",
    "icon theme initial plan",
)
replace(
    "src/system/icon_resolver.cpp",
    """IconResolver::IconResolver() : IconResolver(false) {}

bool IconResolver::checkThemeChanged() {
  auto& state = iconThemeState();
  std::scoped_lock lock(state.mutex);
  IconThemePlan next = buildThemePlan();
""",
    """IconResolver::IconResolver() : IconResolver(false) {}

bool IconResolver::setPreferQsEnvironment(bool enabled) {
  auto& state = iconThemeState();
  std::scoped_lock lock(state.mutex);
  if (state.initialized && state.preferQsEnvironment == enabled) {
    return false;
  }
  IconThemePlan next = buildThemePlan(enabled);
  const bool changed = state.initialized && next.signature != state.plan.signature;
  state.preferQsEnvironment = enabled;
  state.plan = std::move(next);
  state.initialized = true;
  if (changed) {
    ++state.generation;
  }
  return changed;
}

bool IconResolver::checkThemeChanged() {
  auto& state = iconThemeState();
  std::scoped_lock lock(state.mutex);
  IconThemePlan next = buildThemePlan(state.preferQsEnvironment);
""",
    "icon theme live source selection",
)
replace(
    "src/app/application_services.cpp",
    """#include "system/keyboard_backlight_service.h"
#include "system/system_monitor_service.h"
""",
    """#include "system/icon_resolver.h"
#include "system/keyboard_backlight_service.h"
#include "system/system_monitor_service.h"
""",
    "icon resolver application include",
)
replace(
    "src/app/application_services.cpp",
    """  auto applyPasswordMaskStyle = [this]() {
    const auto style = m_configService.config().shell.passwordMaskStyle == PasswordMaskStyle::RandomIcons
        ? Input::PasswordMaskStyle::RandomIcons
        : Input::PasswordMaskStyle::CircleFilled;
    Input::setPasswordMaskStyle(style);
  };
  applyMotionConfig();
  applyStyleConfig();
  applyPasswordMaskStyle();
""",
    """  auto applyPasswordMaskStyle = [this]() {
    const auto style = m_configService.config().shell.passwordMaskStyle == PasswordMaskStyle::RandomIcons
        ? Input::PasswordMaskStyle::RandomIcons
        : Input::PasswordMaskStyle::CircleFilled;
    Input::setPasswordMaskStyle(style);
  };
  auto applyIconThemeSource = [this](bool notifyConsumers) {
    const bool preferQsEnvironment =
        m_configService.config().theme.iconThemeSource == IconThemeSource::QsEnvironment;
    if (IconResolver::setPreferQsEnvironment(preferQsEnvironment) && notifyConsumers) {
      onIconThemeChanged();
    }
  };
  applyMotionConfig();
  applyStyleConfig();
  applyPasswordMaskStyle();
  applyIconThemeSource(false);
""",
    "icon theme source initial application",
)
replace(
    "src/app/application_services.cpp",
    """  m_configService.addReloadCallback(applyPasswordMaskStyle);
  m_configService.addReloadCallback([this]() {
""",
    """  m_configService.addReloadCallback(applyPasswordMaskStyle);
  m_configService.addReloadCallback(
      [this, applyIconThemeSource]() {
        if (m_configService.lastChange().theme) {
          applyIconThemeSource(true);
        }
      },
      "icon-theme-source"
  );
  m_configService.addReloadCallback([this]() {
""",
    "icon theme source reload",
)
replace(
    "src/shell/settings/settings_registry.cpp",
    """    entries.push_back(makeEntry(
        SettingsSection::Appearance, "interface", tr("settings.schema.appearance.corner-roundness.label"),
""",
    """    entries.push_back(makeEntry(
        SettingsSection::Appearance, "interface", tr("settings.schema.appearance.icon-theme-source.label"),
        tr("settings.schema.appearance.icon-theme-source.description"), {"theme", "icon_theme_source"},
        asSegmented(enumSelect(kIconThemeSources, cfg.theme.iconThemeSource)), "icons theme QS_ICON_THEME GTK system"
    ));
    entries.push_back(makeEntry(
        SettingsSection::Appearance, "interface", tr("settings.schema.appearance.corner-roundness.label"),
""",
    "icon theme source settings entry",
)

for locale, system, qs_env, label, description in (
    (
        "en",
        "System / GTK",
        "QS_ICON_THEME",
        "Icon Theme Source",
        "Choose the system icon theme or prefer QS_ICON_THEME with automatic system fallback",
    ),
    (
        "zh-Hans",
        "系统 / GTK",
        "QS_ICON_THEME",
        "图标主题来源",
        "选择系统图标主题，或优先使用 QS_ICON_THEME 并在不可用时自动回退",
    ),
):
    path = Path(f"assets/translations/{locale}.json")
    text = path.read_text()
    options_old = '      "theme": {\n        "mode": {\n'
    options_new = (
        '      "theme": {\n'
        '        "icon-theme-source": {\n'
        f'          "qs-environment": "{qs_env}",\n'
        f'          "system": "{system}"\n'
        '        },\n'
        '        "mode": {\n'
    )
    if text.count(options_old) != 1:
        raise SystemExit(f"icon theme option translation anchor changed in {locale}")
    text = text.replace(options_old, options_new)
    schema_old = '        "input-borders": {\n'
    schema_new = (
        f'        "icon-theme-source": {{\n'
        f'          "description": "{description}",\n'
        f'          "label": "{label}"\n'
        f'        }},\n' + schema_old
    )
    if text.count(schema_old) != 1:
        raise SystemExit(f"icon theme setting translation anchor changed in {locale}")
    path.write_text(text.replace(schema_old, schema_new))
