# NekoMote on niri

`default.nix` builds the pinned `<yourusername>/NekoMote` cross-output gaze fork (based on v0.6.2) and starts one systemd user unit per output as part of `niri.service`. Plasma sessions do not start these units. The Noctalia shell stays enabled; only its own wallpaper and wallpaper automation are turned off in `../noctalia-v5/config.toml`.

- `nekomote-eDP-1.service`: Chocola, BG_07A, interactive, sound initially enabled.
- `nekomote-HDMI-A-1.service`: Vanilla, dynamic BG_01, interactive, initially muted.
- Both start at 30 FPS, use OpenGL and `--gaze desktop`. The application receives cursor position metadata across outputs without requesting image frames. Local clicks, drags and wheel events are not broadcast. Remove `--gaze desktop` for upstream-style local tracking. The launcher waits for a missing output at login; unplugging/replugging after launch is handled by the upstream client.
- `~/.config/nekomote/{eDP-1,HDMI-A-1}.panel.json` are separate, writable settings. Initial values are only seeded when the respective file does not exist. Use the wallpaper panel for later changes, including sound and FPS.
- `~/.local/share/nekomote/assets` points to the fixed asset tree in the Nix store. The program and game-derived assets have separate licensing terms; see their respective upstream repositories.

Inspect without restarting niri:

```sh
systemctl --user status nekomote-eDP-1.service nekomote-HDMI-A-1.service
journalctl --user -b -u nekomote-eDP-1.service -u nekomote-HDMI-A-1.service -n 40 --no-pager
niri msg layers
```

Stopping just the two NekoMote services will not re-enable the old wallpaper. The trial's backed-up configuration, pinned previous Home Manager generation and executable `rollback` are under `~/.local/state/nekomote-backups/20261119-134550/`.
