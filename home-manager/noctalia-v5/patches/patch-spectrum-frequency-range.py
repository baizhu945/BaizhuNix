#!/usr/bin/env python3
"""Expose the shared audio-spectrum frequency range as live configuration."""

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
    """struct AudioConfig {
  bool enableOverdrive = false;
""",
    """struct AudioSpectrumConfig {
  int lowerCutoffHz = 20;
  int upperCutoffHz = 20000;

  bool operator==(const AudioSpectrumConfig&) const = default;
};

struct AudioConfig {
  bool enableOverdrive = false;
""",
    "audio spectrum config type",
)
replace(
    "src/config/config_types.h",
    """  std::string notificationSound;

  bool operator==(const AudioConfig&) const = default;
""",
    """  std::string notificationSound;
  AudioSpectrumConfig spectrum;

  bool operator==(const AudioConfig&) const = default;
""",
    "audio spectrum config field",
)
replace(
    "src/config/schema/config_schema.cpp",
    """  const Schema<AudioConfig>& audioSchema() {
    static const Schema<AudioConfig> s = {
""",
    """  const Schema<AudioSpectrumConfig>& audioSpectrumSchema() {
    static const Schema<AudioSpectrumConfig> s = {
        field(&AudioSpectrumConfig::lowerCutoffHz, "lower_cutoff_hz", Range<std::int64_t>{1, 100000}),
        field(&AudioSpectrumConfig::upperCutoffHz, "upper_cutoff_hz", Range<std::int64_t>{2, 100000}),
        finalize<AudioSpectrumConfig>([](AudioSpectrumConfig& spectrum, std::string_view path, Diagnostics& diag) {
          if (spectrum.lowerCutoffHz >= spectrum.upperCutoffHz) {
            diag.error(std::string(path), "lower_cutoff_hz must be less than upper_cutoff_hz");
          }
        }),
    };
    return s;
  }

  const Schema<AudioConfig>& audioSchema() {
    static const Schema<AudioConfig> s = {
""",
    "audio spectrum schema definition",
)
replace(
    "src/config/schema/config_schema.cpp",
    """        field(&AudioConfig::notificationSound, "notification_sound"),
    };
""",
    """        field(&AudioConfig::notificationSound, "notification_sound"),
        subTable(&AudioConfig::spectrum, "spectrum", audioSpectrumSchema()),
    };
""",
    "audio spectrum schema field",
)
replace(
    "src/pipewire/pipewire_spectrum.h",
    """  void setLowerCutoff(int freq);
  [[nodiscard]] int lowerCutoff() const noexcept { return m_lowerCutoff; }

  void setUpperCutoff(int freq);
""",
    """  void setFrequencyRange(int lowerFreq, int upperFreq);
  void setLowerCutoff(int freq);
  [[nodiscard]] int lowerCutoff() const noexcept { return m_lowerCutoff; }

  void setUpperCutoff(int freq);
""",
    "audio spectrum frequency API",
)
replace(
    "src/pipewire/pipewire_spectrum.cpp",
    """void PipeWireSpectrum::setLowerCutoff(int freq) {
  freq = std::max(1, freq);
  if (freq == m_lowerCutoff) {
    return;
  }
  m_lowerCutoff = freq;
  computeAnalysisBandBins();
}

void PipeWireSpectrum::setUpperCutoff(int freq) {
  freq = std::max(m_lowerCutoff + 1, freq);
  if (freq == m_upperCutoff) {
    return;
  }
  m_upperCutoff = freq;
  computeAnalysisBandBins();
}
""",
    """void PipeWireSpectrum::setFrequencyRange(int lowerFreq, int upperFreq) {
  lowerFreq = std::max(1, lowerFreq);
  upperFreq = std::max(lowerFreq + 1, upperFreq);
  if (lowerFreq == m_lowerCutoff && upperFreq == m_upperCutoff) {
    return;
  }
  m_lowerCutoff = lowerFreq;
  m_upperCutoff = upperFreq;
  computeAnalysisBandBins();
  for (auto& [id, state] : m_listeners) {
    (void)id;
    resetListenerState(state, true);
  }
  for (const auto& [id, state] : m_listeners) {
    (void)state;
    emitChanged(id);
  }
}

void PipeWireSpectrum::setLowerCutoff(int freq) { setFrequencyRange(freq, m_upperCutoff); }

void PipeWireSpectrum::setUpperCutoff(int freq) { setFrequencyRange(m_lowerCutoff, freq); }
""",
    "audio spectrum atomic frequency update",
)
replace(
    "src/app/application_services.cpp",
    """    m_pipewireSpectrum = std::make_unique<PipeWireSpectrum>(*m_pipewireService);
    m_soundPlayer = std::make_shared<SoundPlayer>(m_pipewireService->loop());
""",
    """    m_pipewireSpectrum = std::make_unique<PipeWireSpectrum>(*m_pipewireService);
    auto applySpectrumConfig = [this]() {
      if (m_pipewireSpectrum == nullptr) {
        return;
      }
      const auto& spectrum = m_configService.config().audio.spectrum;
      m_pipewireSpectrum->setFrequencyRange(spectrum.lowerCutoffHz, spectrum.upperCutoffHz);
    };
    applySpectrumConfig();
    m_configService.addReloadCallback(
        [this, applySpectrumConfig]() {
          if (m_configService.lastChange().audio) {
            applySpectrumConfig();
          }
        },
        "audio-spectrum"
    );
    m_soundPlayer = std::make_shared<SoundPlayer>(m_pipewireService->loop());
""",
    "audio spectrum config lifecycle",
)
replace(
    "src/shell/settings/settings_registry.cpp",
    """    entries.push_back(makeEntry(
        SettingsSection::Services, "audio", tr("settings.schema.services.shell-sounds.label"),
""",
    """    entries.push_back(makeEntry(
        SettingsSection::Services, "audio", tr("settings.schema.services.spectrum-lower-cutoff.label"),
        tr("settings.schema.services.spectrum-lower-cutoff.description"),
        {"audio", "spectrum", "lower_cutoff_hz"},
        StepperSetting{.value = cfg.audio.spectrum.lowerCutoffHz, .minValue = 1, .maxValue = 20000, .step = 10,
                       .valueSuffix = "Hz"},
        "audio spectrum visualizer frequency low cutoff", true
    ));
    entries.push_back(makeEntry(
        SettingsSection::Services, "audio", tr("settings.schema.services.spectrum-upper-cutoff.label"),
        tr("settings.schema.services.spectrum-upper-cutoff.description"),
        {"audio", "spectrum", "upper_cutoff_hz"},
        StepperSetting{.value = cfg.audio.spectrum.upperCutoffHz, .minValue = 2, .maxValue = 48000, .step = 100,
                       .valueSuffix = "Hz"},
        "audio spectrum visualizer frequency high cutoff", true
    ));
    entries.push_back(makeEntry(
        SettingsSection::Services, "audio", tr("settings.schema.services.shell-sounds.label"),
""",
    "audio spectrum settings entries",
)

for locale, low_label, low_desc, high_label, high_desc in (
    (
        "en",
        "Spectrum Lower Cutoff",
        "Lowest frequency analyzed by audio visualizers",
        "Spectrum Upper Cutoff",
        "Highest frequency analyzed by audio visualizers",
    ),
    (
        "zh-Hans",
        "频谱最低频率",
        "音频可视化器分析的最低频率",
        "频谱最高频率",
        "音频可视化器分析的最高频率",
    ),
):
    path = Path(f"assets/translations/{locale}.json")
    text = path.read_text()
    old = '        "audio-overdrive": {\n'
    new = (
        f'        "spectrum-lower-cutoff": {{\n'
        f'          "description": "{low_desc}",\n'
        f'          "label": "{low_label}"\n'
        f'        }},\n'
        f'        "spectrum-upper-cutoff": {{\n'
        f'          "description": "{high_desc}",\n'
        f'          "label": "{high_label}"\n'
        f'        }},\n' + old
    )
    if text.count(old) != 1:
        raise SystemExit(f"audio spectrum translation anchor changed in {locale}")
    path.write_text(text.replace(old, new))
