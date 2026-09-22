# Noctalia V5 source patches

Each script patches one compatibility concern and aborts when its expected upstream source no longer matches. `noctalia-v5.nix` applies them in the order listed below.

1. `patch-media-mini.py` — add the APIs required by the optional V4 MediaMini plugin; the native `media` widget remains available.
2. `patch-stable-output.py` — stable make/model/serial identities for desktop-widget outputs.
3. `patch-transparent-bar-blur.py` — suppress compositor blur for a fully transparent bar.
4. `patch-screenshot-secondary-click.py` — add `widget.*.secondary_click = "menu" | "fullscreen"` (native default: `menu`).
5. `patch-panel-prewarm-blur.py` — disable panel blur prewarming.
6. `patch-icon-raster-quality.py` — improve launcher, workspace/taskbar, and tray HiDPI icon rasterization.
7. `patch-brightness-fallback.py` — add `widget.*.show_when_unavailable` (native default: `false`).
8. `patch-panel-click-anchor.py` — anchor attached panels to the widget that opened them.
9. `patch-panel-background-opacity.py` — keep panel opacity independent of transparent bar opacity.
10. `patch-panel-compositor-blur.py` — add `shell.panel.compositor_blur_enabled` (native default: `true`).
11. `patch-icon-theme-environment.py` — add `theme.icon_theme_source = "system" | "qs_environment"` (native default: `system`).
12. `patch-notification-timeouts.py` — add native/application and urgency-specific notification timeout policies (native default: application timeout).
13. `patch-deskvis-renderer.py` — add a per-instance `visualizer_profile = "native" | "v4"` renderer choice (native default: `native`).
14. `patch-deskvis-smoothing.py` — select V4 attack/decay only for desktop visualizers using the V4 profile.
15. `patch-deskvis-idle-fade.py` — select the 600 ms fade only for desktop visualizers using the V4 profile.
16. `patch-spectrum-frequency-range.py` — add configurable shared spectrum cutoffs (native defaults: 20–20000 Hz).
17. `patch-osd-timeout.py` — add configurable OSD auto-hide delay (native default: 1400 ms).
18. `patch-taskbar-title-color.py` — make flat taskbar window titles honor the widget foreground color (native fallback remains `on_surface`).
