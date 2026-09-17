#!/usr/bin/env python3
"""Give desktop widgets stable make/model/serial output identities."""

from pathlib import Path


def replace(path: str, old: str, new: str, label: str) -> None:
    target = Path(path)
    text = target.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match in {path}, found {count}")
    target.write_text(text.replace(old, new))


replace(
    "src/shell/desktop/desktop_widget_layout.h",
    """  inline std::string outputKey(const WaylandOutput& output) {
    if (!output.connectorName.empty()) {
      return output.connectorName;
    }
    return std::to_string(output.name);
  }

  inline const WaylandOutput* findOutputByKey(const WaylandConnection& wayland, const std::string& key) {
""",
    """  // Connector names such as eDP-1/eDP-2 are allocation-order dependent.
  // Prefer a hardware identity from wlr-output-management and include a real
  // serial when the monitor exposes one. The connector remains a legacy alias
  // in findOutputByKey(), so old settings migrate without disappearing.
  inline std::string outputKey(const WaylandOutput& output) {
    if (!output.model.empty()) {
      std::string key = "hardware:";
      key += output.make.empty() ? "*" : output.make;
      key += '|';
      key += output.model;
      if (!output.serialNumber.empty() && output.serialNumber != "Unknown") {
        key += '|';
        key += output.serialNumber;
      }
      return key;
    }
    if (!output.connectorName.empty()) {
      return output.connectorName;
    }
    return std::to_string(output.name);
  }

  inline const WaylandOutput* findOutputByKey(const WaylandConnection& wayland, const std::string& key) {
""",
    "stable desktop output key",
)

replace(
    "src/shell/desktop/desktop_widget_layout.h",
    """      if (outputKey(output) == key) {
        return &output;
      }
""",
    """      if (outputKey(output) == key || output.connectorName == key || output.description == key) {
        return &output;
      }
""",
    "stable and legacy desktop output lookup",
)
