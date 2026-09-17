#!/usr/bin/env python3
"""Make external notification timeout policy and urgency durations configurable."""

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
    """struct NotificationConfig {
""",
    """enum class NotificationTimeoutMode : std::uint8_t {
  Native = 0,
  Urgency = 1,
};

constexpr EnumOption<NotificationTimeoutMode> kNotificationTimeoutModes[] = {
    {NotificationTimeoutMode::Native, "native", "settings.options.notification-timeout.native"},
    {NotificationTimeoutMode::Urgency, "urgency", "settings.options.notification-timeout.urgency"},
};

struct NotificationTimeoutConfig {
  NotificationTimeoutMode mode = NotificationTimeoutMode::Native;
  int lowMs = 2000;
  int normalMs = 3000;
  int criticalMs = 5000;

  bool operator==(const NotificationTimeoutConfig&) const = default;
};

struct NotificationConfig {
""",
    "notification timeout types",
)
replace(
    "src/config/config_types.h",
    """  int maxVisible = 0; // 0 = unlimited (space-based only)

  std::vector<NotificationFilterConfig> filters;
""",
    """  int maxVisible = 0; // 0 = unlimited (space-based only)
  NotificationTimeoutConfig timeout;

  std::vector<NotificationFilterConfig> filters;
""",
    "notification timeout config field",
)
replace(
    "src/config/schema/config_schema.cpp",
    """  const Schema<NotificationConfig>& notificationSchema() {
""",
    """  const Schema<NotificationTimeoutConfig>& notificationTimeoutSchema() {
    static const Schema<NotificationTimeoutConfig> s = {
        enumField(&NotificationTimeoutConfig::mode, "mode", kNotificationTimeoutModes),
        field(&NotificationTimeoutConfig::lowMs, "low_ms", Range<std::int64_t>{0, 3600000}),
        field(&NotificationTimeoutConfig::normalMs, "normal_ms", Range<std::int64_t>{0, 3600000}),
        field(&NotificationTimeoutConfig::criticalMs, "critical_ms", Range<std::int64_t>{0, 3600000}),
    };
    return s;
  }

  const Schema<NotificationConfig>& notificationSchema() {
""",
    "notification timeout schema definition",
)
replace(
    "src/config/schema/config_schema.cpp",
    """        field(&NotificationConfig::maxVisible, "max_visible", Range<std::int64_t>{0, 20}),
        custom<NotificationConfig>(
""",
    """        field(&NotificationConfig::maxVisible, "max_visible", Range<std::int64_t>{0, 20}),
        subTable(&NotificationConfig::timeout, "timeout", notificationTimeoutSchema()),
        custom<NotificationConfig>(
""",
    "notification timeout schema field",
)
replace(
    "src/notification/notification_manager.h",
    """  void setFilters(std::vector<NotificationFilterConfig> filters);
  [[nodiscard]] const std::vector<NotificationFilterConfig>& filters() const noexcept;
""",
    """  void setFilters(std::vector<NotificationFilterConfig> filters);
  [[nodiscard]] const std::vector<NotificationFilterConfig>& filters() const noexcept;
  void setTimeoutConfig(NotificationTimeoutConfig config);
""",
    "notification timeout manager API",
)
replace(
    "src/notification/notification_manager.h",
    """  std::vector<NotificationFilterConfig> m_filters;
  /// Expired notifications with actions: NotificationClosed deferred until dismiss, action, or history removal.
""",
    """  std::vector<NotificationFilterConfig> m_filters;
  NotificationTimeoutConfig m_timeoutConfig;
  /// Expired notifications with actions: NotificationClosed deferred until dismiss, action, or history removal.
""",
    "notification timeout manager state",
)
replace(
    "src/notification/notification_manager.cpp",
    """  const auto& forcedId = request.forcedId;

  if (actions.size() > kMaxNotificationActions * 2) {
""",
    """  const auto& forcedId = request.forcedId;

  if (origin == NotificationOrigin::External && m_timeoutConfig.mode == NotificationTimeoutMode::Urgency) {
    switch (urgency) {
    case Urgency::Low:
      timeout = m_timeoutConfig.lowMs;
      break;
    case Urgency::Normal:
      timeout = m_timeoutConfig.normalMs;
      break;
    case Urgency::Critical:
      timeout = m_timeoutConfig.criticalMs;
      break;
    }
  }

  if (actions.size() > kMaxNotificationActions * 2) {
""",
    "notification timeout policy application",
)
replace(
    "src/notification/notification_manager.cpp",
    """const std::vector<NotificationFilterConfig>& NotificationManager::filters() const noexcept { return m_filters; }

NotificationManager::ExternalNotificationDispatch NotificationManager::evaluateExternalDispatch(
""",
    """const std::vector<NotificationFilterConfig>& NotificationManager::filters() const noexcept { return m_filters; }

void NotificationManager::setTimeoutConfig(NotificationTimeoutConfig config) { m_timeoutConfig = config; }

NotificationManager::ExternalNotificationDispatch NotificationManager::evaluateExternalDispatch(
""",
    "notification timeout policy setter",
)
replace(
    "src/app/application_ui.cpp",
    """  auto applyNotificationFilterConfig = [this]() {
    m_notificationManager.setFilters(m_configService.config().notification.filters);
  };
""",
    """  auto applyNotificationFilterConfig = [this]() {
    m_notificationManager.setFilters(m_configService.config().notification.filters);
  };
  auto applyNotificationTimeoutConfig = [this]() {
    m_notificationManager.setTimeoutConfig(m_configService.config().notification.timeout);
  };
""",
    "notification timeout application callback",
)
replace(
    "src/app/application_ui.cpp",
    """  applyNotificationFilterConfig();
  m_configService.addReloadCallback(applyNotificationFilterConfig);
""",
    """  applyNotificationFilterConfig();
  m_configService.addReloadCallback(applyNotificationFilterConfig);
  applyNotificationTimeoutConfig();
  m_configService.addReloadCallback(applyNotificationTimeoutConfig);
""",
    "notification timeout initial and reload application",
)
replace(
    "src/shell/settings/settings_registry.cpp",
    """    entries.push_back(makeEntry(
        SettingsSection::Notifications, "toasts", tr("settings.schema.notifications.toast-opacity.label"),
""",
    """    entries.push_back(makeEntry(
        SettingsSection::Notifications, "toasts", tr("settings.schema.notifications.timeout-mode.label"),
        tr("settings.schema.notifications.timeout-mode.description"), {"notification", "timeout", "mode"},
        asSegmented(enumSelect(kNotificationTimeoutModes, cfg.notification.timeout.mode)),
        "notification duration expiry timeout urgency"
    ));
    const SettingVisibility urgencyTimeouts = [](const Config& c) {
      return c.notification.timeout.mode == NotificationTimeoutMode::Urgency;
    };
    auto addNotificationTimeout = [&](std::string_view key, std::string_view labelKey, int value) {
      auto entry = makeEntry(
          SettingsSection::Notifications, "toasts", tr(labelKey),
          tr("settings.schema.notifications.timeout-duration.description"),
          {"notification", "timeout", std::string(key)},
          StepperSetting{.value = value, .minValue = 0, .maxValue = 60000, .step = 100, .valueSuffix = "ms"},
          "notification duration expiry timeout urgency"
      );
      entry.visibleWhen = urgencyTimeouts;
      entries.push_back(std::move(entry));
    };
    addNotificationTimeout("low_ms", "settings.schema.notifications.timeout-low.label", cfg.notification.timeout.lowMs);
    addNotificationTimeout(
        "normal_ms", "settings.schema.notifications.timeout-normal.label", cfg.notification.timeout.normalMs
    );
    addNotificationTimeout(
        "critical_ms", "settings.schema.notifications.timeout-critical.label", cfg.notification.timeout.criticalMs
    );
    entries.push_back(makeEntry(
        SettingsSection::Notifications, "toasts", tr("settings.schema.notifications.toast-opacity.label"),
""",
    "notification timeout settings entries",
)

for locale, native, urgency, mode_label, mode_desc, duration_desc, low, normal, critical in (
    (
        "en",
        "Native",
        "By Urgency",
        "Timeout Policy",
        "Use application-provided timeouts or choose durations from notification urgency",
        "Duration before the notification closes; zero keeps it until dismissed",
        "Low Priority Duration",
        "Normal Priority Duration",
        "Critical Priority Duration",
    ),
    (
        "zh-Hans",
        "原生",
        "按紧急程度",
        "超时策略",
        "使用应用提供的超时，或根据通知紧急程度选择持续时间",
        "通知关闭前的持续时间；设为零则保留至手动关闭",
        "低优先级持续时间",
        "普通优先级持续时间",
        "紧急通知持续时间",
    ),
):
    path = Path(f"assets/translations/{locale}.json")
    text = path.read_text()
    options_old = '      "orientation": {\n'
    options_new = (
        '      "notification-timeout": {\n'
        f'        "native": "{native}",\n'
        f'        "urgency": "{urgency}"\n'
        '      },\n' + options_old
    )
    if text.count(options_old) != 1:
        raise SystemExit(f"notification timeout option translation anchor changed in {locale}")
    text = text.replace(options_old, options_new)
    schema_old = '        "toast-opacity": {\n'
    schema_new = (
        f'        "timeout-mode": {{\n'
        f'          "description": "{mode_desc}",\n'
        f'          "label": "{mode_label}"\n'
        f'        }},\n'
        f'        "timeout-duration": {{\n'
        f'          "description": "{duration_desc}"\n'
        f'        }},\n'
        f'        "timeout-low": {{\n'
        f'          "label": "{low}"\n'
        f'        }},\n'
        f'        "timeout-normal": {{\n'
        f'          "label": "{normal}"\n'
        f'        }},\n'
        f'        "timeout-critical": {{\n'
        f'          "label": "{critical}"\n'
        f'        }},\n' + schema_old
    )
    if text.count(schema_old) != 1:
        raise SystemExit(f"notification timeout setting translation anchor changed in {locale}")
    path.write_text(text.replace(schema_old, schema_new))
