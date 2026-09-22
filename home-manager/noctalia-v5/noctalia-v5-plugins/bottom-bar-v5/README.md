# Bottom Bar Utilities

Local Noctalia V5 plugin used by the secondary bottom bar.

It provides:

- a native `hyprpicker`-based color picker with format conversion and persistent recent-color history;
- a one-second battery power draw monitor and battery information panel;
- one combined display hub opening both Niri output management (enable/disable, mode, scale, DDC brightness, and DDC contrast) and `wl-mirror` display mirroring with active-process tracking.

The plugin is self-contained. The center application list uses Noctalia's native flat taskbar with window titles.

## Attribution

This implementation was written for Noctalia's Luau plugin API and retains attribution for the earlier widgets that inspired several functions:

- Power Usage Monitor by Daniel-42-z.
- Display Manager by felri, originally Apache-2.0 licensed.
- Display Mirror by jfchenier, originally GPL-3.0 licensed.

Because the combined compatibility plugin implements the GPL-licensed mirror workflow, this plugin is distributed under GPL-3.0-only.
