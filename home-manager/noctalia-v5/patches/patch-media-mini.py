#!/usr/bin/env python3
"""Extend Noctalia 5.1's Luau UI just enough for the V4 MediaMini port."""

from pathlib import Path


def replace(path: str, old: str, new: str, label: str) -> None:
    target = Path(path)
    text = target.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match in {path}, found {count}")
    target.write_text(text.replace(old, new))


# Thread-safe MPRIS snapshot published by Application and read by plugin workers.
replace(
    "src/scripting/script_api_context.h",
    """  struct ScriptOutputInfo {
    std::string name; // DRM connector name, e.g. \"DP-1\"
    std::string description;
    int width = 0; // logical size
    int height = 0;
    int x = 0; // position in logical output space
    int y = 0;
    int scale = 1;
    bool focused = false;
  };
""",
    """  struct ScriptOutputInfo {
    std::string name; // DRM connector name, e.g. \"DP-1\"
    std::string description;
    int width = 0; // logical size
    int height = 0;
    int x = 0; // position in logical output space
    int y = 0;
    int scale = 1;
    bool focused = false;
  };

  // Immutable active-player snapshot for Luau bar plugins. Application copies
  // it on the main thread; plugin workers never race MprisService internals.
  struct ScriptMediaInfo {
    std::string busName;
    std::string identity;
    std::string playbackStatus;
    std::string title;
    std::string artist;
    std::string album;
    std::string artUrl;
    std::int64_t positionUs = 0;
    std::int64_t lengthUs = 0;
    double sampledAtMs = 0.0;
    bool canPlay = false;
    bool canPause = false;
    bool canGoNext = false;
    bool canGoPrevious = false;
  };
""",
    "media snapshot struct",
)

replace(
    "src/scripting/script_api_context.h",
    """    [[nodiscard]] std::vector<ScriptOutputInfo> outputs() const {
      std::scoped_lock lock(m_mutex);
      return m_outputs;
    }

    // Effective shell config, serialized via config_export::serialize — published on the
""",
    """    [[nodiscard]] std::vector<ScriptOutputInfo> outputs() const {
      std::scoped_lock lock(m_mutex);
      return m_outputs;
    }

    void setMediaInfo(std::optional<ScriptMediaInfo> media) {
      std::scoped_lock lock(m_mutex);
      m_mediaInfo = std::move(media);
    }

    [[nodiscard]] std::optional<ScriptMediaInfo> mediaInfo() const {
      std::scoped_lock lock(m_mutex);
      return m_mediaInfo;
    }

    // Effective shell config, serialized via config_export::serialize — published on the
""",
    "media snapshot accessors",
)

replace(
    "src/scripting/script_api_context.h",
    """    std::vector<ScriptOutputInfo> m_outputs;
    std::unordered_map<std::string, std::string> m_wallpaperPaths;
    std::optional<std::string> m_clipboardText;
""",
    """    std::vector<ScriptOutputInfo> m_outputs;
    std::unordered_map<std::string, std::string> m_wallpaperPaths;
    std::optional<std::string> m_clipboardText;
    std::optional<ScriptMediaInfo> m_mediaInfo;
""",
    "media snapshot storage",
)

replace(
    "src/app/application_services.cpp",
    """      m_mprisService = std::make_unique<MprisService>(*m_bus);
      auto applyMprisConfig = [this]() {
""",
    """      m_mprisService = std::make_unique<MprisService>(*m_bus);
      auto publishMpris = [this]() {
        std::optional<scripting::ScriptMediaInfo> snapshot;
        if (m_mprisService != nullptr) {
          if (const auto active = m_mprisService->activePlayer(); active.has_value()) {
            snapshot = scripting::ScriptMediaInfo{
                .busName = active->busName,
                .identity = active->identity,
                .playbackStatus = active->playbackStatus,
                .title = active->title,
                .artist = joinedArtists(active->artists),
                .album = active->album,
                .artUrl = active->artUrl,
                .positionUs = active->positionUs,
                .lengthUs = active->lengthUs,
                .sampledAtMs = std::chrono::duration<double, std::milli>(
                    std::chrono::system_clock::now().time_since_epoch()
                ).count(),
                .canPlay = active->canPlay,
                .canPause = active->canPause,
                .canGoNext = active->canGoNext,
                .canGoPrevious = active->canGoPrevious,
            };
          }
        }
        m_scriptApi.setMediaInfo(std::move(snapshot));
      };
      publishMpris();
      auto applyMprisConfig = [this]() {
""",
    "publish MPRIS snapshot",
)

replace(
    "src/app/application_services.cpp",
    """      m_mprisService->setChangeCallback([this, shouldRefreshControlCenter]() {
        m_bar.refresh();
""",
    """      m_mprisService->setChangeCallback([this, shouldRefreshControlCenter, publishMpris]() {
        publishMpris();
        m_bar.refresh();
""",
    "refresh MPRIS snapshot",
)

replace(
    "src/app/application_services.cpp",
    """      m_mprisService.reset();
      m_lockScreen.setLoginBoxServices(&m_sessionActionRunner, nullptr, &m_weatherService, &m_httpClient);
""",
    """      m_mprisService.reset();
      m_scriptApi.setMediaInfo(std::nullopt);
      m_lockScreen.setLoginBoxServices(&m_sessionActionRunner, nullptr, &m_weatherService, &m_httpClient);
""",
    "clear MPRIS snapshot",
)

# Luau noctalia.mediaInfo().
replace(
    "src/scripting/luau_host.cpp",
    """  // The host's system monitor, or nullptr when it is unavailable: either it failed to construct or
""",
    """  // mediaInfo() -> active MPRIS player snapshot, or nil when no player exists.
  int luau_mediaInfo(lua_State* L) {
    auto* host = hostForState(L);
    if (host == nullptr) {
      lua_pushnil(L);
      return 1;
    }
    const auto media = host->api().mediaInfo();
    if (!media.has_value()) {
      lua_pushnil(L);
      return 1;
    }
    lua_createtable(L, 0, 14);
    setTableString(L, \"busName\", media->busName);
    setTableString(L, \"identity\", media->identity);
    setTableString(L, \"playbackStatus\", media->playbackStatus);
    setTableString(L, \"title\", media->title);
    setTableString(L, \"artist\", media->artist);
    setTableString(L, \"album\", media->album);
    setTableString(L, \"artUrl\", media->artUrl);
    setTableNumber(L, \"positionUs\", static_cast<double>(media->positionUs));
    setTableNumber(L, \"lengthUs\", static_cast<double>(media->lengthUs));
    setTableNumber(L, \"sampledAtMs\", media->sampledAtMs);
    setTableBool(L, \"canPlay\", media->canPlay);
    setTableBool(L, \"canPause\", media->canPause);
    setTableBool(L, \"canGoNext\", media->canGoNext);
    setTableBool(L, \"canGoPrevious\", media->canGoPrevious);
    return 1;
  }

  // The host's system monitor, or nullptr when it is unavailable: either it failed to construct or
""",
    "Luau mediaInfo binding",
)

replace(
    "src/scripting/luau_host.cpp",
    """      {\"outputs\", luau_outputs},
      {\"systemStats\", luau_systemStats},
""",
    """      {\"outputs\", luau_outputs},
      {\"mediaInfo\", luau_mediaInfo},
      {\"systemStats\", luau_systemStats},
""",
    "register mediaInfo",
)

# Expose the existing native CountdownRing as ui.ring. Negative Flex gaps are
# already supported and let a plugin layer ring/image and graph/content lanes.
replace(
    "src/scripting/ui_prelude.h",
    'ui.progress = ctor("progress")\n',
    'ui.progress = ctor("progress")\nui.ring = ctor("ring")\n',
    "ui.ring constructor",
)

replace(
    "src/ui/ui_tree_reconciler.cpp",
    '#include "ui/controls/button.h"\n',
    '#include "ui/controls/button.h"\n#include "ui/controls/countdown_ring.h"\n',
    "countdown ring include",
)

replace(
    "src/ui/ui_tree_reconciler.cpp",
    """      static const std::unordered_set<std::string> kProgress = {\"width\",    \"height\", \"flexGrow\", \"opacity\", \"visible\",
                                                                \"progress\", \"fill\",   \"track\",    \"radius\"};
""",
    """      static const std::unordered_set<std::string> kProgress = {\"width\",    \"height\", \"flexGrow\", \"opacity\", \"visible\",
                                                                \"progress\", \"fill\",   \"track\",    \"radius\"};
      static const std::unordered_set<std::string> kRing = {
          \"width\", \"height\", \"flexGrow\", \"opacity\", \"visible\", \"size\", \"thickness\", \"progress\", \"color\"
      };
""",
    "ring props",
)

replace(
    "src/ui/ui_tree_reconciler.cpp",
    """      if (type == \"progress\") {
        return kProgress;
      }
      if (type == \"button\") {
""",
    """      if (type == \"progress\") {
        return kProgress;
      }
      if (type == \"ring\") {
        return kRing;
      }
      if (type == \"button\") {
""",
    "ring known props",
)

replace(
    "src/ui/ui_tree_reconciler.cpp",
    """    if (desired.type == \"progress\") {
      return std::make_unique<ProgressBar>();
    }
    if (desired.type == \"button\") {
""",
    """    if (desired.type == \"progress\") {
      return std::make_unique<ProgressBar>();
    }
    if (desired.type == \"ring\") {
      return std::make_unique<CountdownRing>();
    }
    if (desired.type == \"button\") {
""",
    "create ring control",
)

# Add an exact V4 NWaveSpectrum mode to ui.graph. The current V4 setting is
# spectrumMirrored=false, so it uses the shader's linear frequency mapping,
# cubic-Hermite interpolation, centered amplitude fill, and ~1.5px AA edge.
replace(
    "src/render/core/render_styles.h",
    """  float graphFillOpacity = 0.15F;
  float aaSize = 0.5F;
};
""",
    """  float graphFillOpacity = 0.15F;
  float aaSize = 0.5F;
  bool waveSpectrum = false;
};
""",
    "graph wave style",
)

replace(
    "src/render/scene/graph_node.h",
    """  void setAaSize(float size) {
    if (m_style.aaSize == size)
      return;
    m_style.aaSize = size;
    markPaintDirty();
  }
""",
    """  void setAaSize(float size) {
    if (m_style.aaSize == size)
      return;
    m_style.aaSize = size;
    markPaintDirty();
  }

  void setWaveSpectrum(bool wave) {
    if (m_style.waveSpectrum == wave)
      return;
    m_style.waveSpectrum = wave;
    markPaintDirty();
  }
""",
    "graph node wave setter",
)

replace(
    "src/ui/controls/graph.h",
    """  void setLineWidth(float width);
  void setFillOpacity(float opacity);
""",
    """  void setLineWidth(float width);
  void setFillOpacity(float opacity);
  void setWaveSpectrum(bool wave);
""",
    "graph control wave declaration",
)

replace(
    "src/ui/controls/graph.cpp",
    """void Graph::setFillOpacity(float opacity) {
  m_fillOpacity = opacity;
  if (m_node != nullptr) {
    m_node->setGraphFillOpacity(opacity);
  }
}
""",
    """void Graph::setFillOpacity(float opacity) {
  m_fillOpacity = opacity;
  if (m_node != nullptr) {
    m_node->setGraphFillOpacity(opacity);
  }
}

void Graph::setWaveSpectrum(bool wave) {
  if (m_node != nullptr) {
    m_node->setWaveSpectrum(wave);
  }
}
""",
    "graph control wave implementation",
)

replace(
    "src/ui/ui_tree_reconciler.cpp",
    """          \"color\", \"color2\", \"lineWidth\", \"fillOpacity\", \"onPointerMove\", \"onPointerLeave\"
""",
    """          \"color\", \"color2\", \"lineWidth\", \"fillOpacity\", \"wave\", \"onPointerMove\", \"onPointerLeave\"
""",
    "graph wave prop",
)

replace(
    "src/ui/ui_tree_reconciler.cpp",
    """      if (const double* fillOpacity = numProp(desired, \"fillOpacity\")) {
        graph->setFillOpacity(std::clamp(static_cast<float>(*fillOpacity), 0.0F, 1.0F));
      }
      const float graphWidth = width != nullptr ? scaled(*width) : graph->width();
""",
    """      if (const double* fillOpacity = numProp(desired, \"fillOpacity\")) {
        graph->setFillOpacity(std::clamp(static_cast<float>(*fillOpacity), 0.0F, 1.0F));
      }
      graph->setWaveSpectrum(boolProp(desired, \"wave\") != nullptr && *boolProp(desired, \"wave\"));
      const float graphWidth = width != nullptr ? scaled(*width) : graph->width();
""",
    "apply graph wave prop",
)

replace(
    "src/render/programs/graph_program.h",
    """  GLint m_graphFillOpacityLoc = -1;
  GLint m_texWidthLoc = -1;
""",
    """  GLint m_graphFillOpacityLoc = -1;
  GLint m_waveSpectrumLoc = -1;
  GLint m_texWidthLoc = -1;
""",
    "graph wave uniform member",
)

replace(
    "src/render/programs/graph_program.cpp",
    """uniform float u_graph_fill_opacity;
uniform float u_tex_width;
""",
    """uniform float u_graph_fill_opacity;
uniform float u_wave_spectrum;
uniform float u_tex_width;
""",
    "graph wave shader uniform",
)

replace(
    "src/render/programs/graph_program.cpp",
    """float segDistSq(vec2 p, vec2 a, vec2 b) {
""",
    """float evalWave(float dataIdx, int ch) {
    float i = floor(dataIdx);
    float t = dataIdx - i;
    return clamp(cubicHermite(
        fetchData(i - 1.0, ch),
        fetchData(i, ch),
        fetchData(i + 1.0, ch),
        fetchData(i + 2.0, ch),
        t
    ), 0.0, 1.0);
}

float segDistSq(vec2 p, vec2 a, vec2 b) {
""",
    "graph wave curve evaluator",
)

replace(
    "src/render/programs/graph_program.cpp",
    """    vec4 result = vec4(0.0);
    float halfW = u_line_width * 0.5;

    if (u_count1 >= 4.0) {
""",
    """    vec4 result = vec4(0.0);
    float halfW = u_line_width * 0.5;

    if (u_wave_spectrum > 0.5 && u_count1 >= 2.0) {
        float dataIdx = uv.x * max(u_count1 - 1.0, 1.0);
        float amplitude = evalWave(dataIdx, 0);
        float halfAmp = amplitude * 0.5;
        float distFromMid = abs(uv.y - 0.5);
        float edge = 1.5 / max(u_res_y, 1.0);
        float mask = smoothstep(halfAmp + edge, halfAmp - edge, distFromMid);
        float a = mask * u_line_color1.a;
        gl_FragColor = vec4(u_line_color1.rgb * a, a);
        return;
    }

    if (u_count1 >= 4.0) {
""",
    "graph exact wave shader",
)

replace(
    "src/render/programs/graph_program.cpp",
    """  m_graphFillOpacityLoc = glGetUniformLocation(id, \"u_graph_fill_opacity\");
  m_texWidthLoc = glGetUniformLocation(id, \"u_tex_width\");
""",
    """  m_graphFillOpacityLoc = glGetUniformLocation(id, \"u_graph_fill_opacity\");
  m_waveSpectrumLoc = glGetUniformLocation(id, \"u_wave_spectrum\");
  m_texWidthLoc = glGetUniformLocation(id, \"u_tex_width\");
""",
    "graph wave uniform location",
)

replace(
    "src/render/programs/graph_program.cpp",
    """  m_graphFillOpacityLoc = -1;
  m_texWidthLoc = -1;
""",
    """  m_graphFillOpacityLoc = -1;
  m_waveSpectrumLoc = -1;
  m_texWidthLoc = -1;
""",
    "graph wave uniform reset",
)

replace(
    "src/render/programs/graph_program.cpp",
    """  glUniform1f(m_graphFillOpacityLoc, style.graphFillOpacity);
  glUniform1f(m_texWidthLoc, static_cast<float>(texWidth));
""",
    """  glUniform1f(m_graphFillOpacityLoc, style.graphFillOpacity);
  glUniform1f(m_waveSpectrumLoc, style.waveSpectrum ? 1.0F : 0.0F);
  glUniform1f(m_texWidthLoc, static_cast<float>(texWidth));
""",
    "upload graph wave uniform",
)

replace(
    "src/ui/ui_tree_reconciler.cpp",
    """    if (desired.type == \"button\") {
      auto* button = static_cast<Button*>(node);
""",
    """    if (desired.type == \"ring\") {
      auto* ring = static_cast<CountdownRing*>(node);
      const double* size = numProp(desired, \"size\");
      ring->setRingSize(scaled(size != nullptr ? *size : 19.0));
      if (const double* thickness = numProp(desired, \"thickness\")) {
        ring->setThickness(scaled(*thickness));
      }
      if (const double* value = numProp(desired, \"progress\")) {
        ring->setProgress(std::clamp(static_cast<float>(*value), 0.0F, 1.0F));
      }
      if (auto color = parseColor(desired, \"color\")) {
        ring->setColor(*color);
      }
      return;
    }

    if (desired.type == \"button\") {
      auto* button = static_cast<Button*>(node);
""",
    "apply ring props",
)
