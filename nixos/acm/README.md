# /etc/nixos/acm -- ACM-equivalent display colour management

This directory contains the declarative Nix configuration for the Linux ACM
equivalent (see `~/Code/acm-re/linux/README.md` for the full documentation).

* `package.nix` -- reproducible derivation for `acm-ctl` (colour engine +
  KMS/Wayland appliers; `doCheck = true` runs the 73-check test suite during the
  build, including byte-for-byte comparison with Microsoft's `dwmcore.dll`
  colour tables).
* `module.nix`  -- the NixOS module (`services.acm.*`): installs the package,
  generates `/etc/acm/displays.conf`, grants DRM access, optional system daemon
  and optional `vkms` loading for `acm-ctl selftest`.

Enable it in `configuration.nix`:

```nix
imports = [ ./acm/module.nix ];
services.acm = {
  enable = true;
  user = "<yourusername>";
  displays = {
    "eDP-1"    = { mode = "auto"; };
    "HDMI-A-1" = { mode = "auto"; };
  };
};
```

The session daemon (which applies the transform under a Wayland compositor via
`wlr-gamma-control`) is configured per-user in
`~/.config/home-manager/acm.nix`; it writes `~/.config/acm/displays.conf` and the
`acm.service` systemd **user** unit.

## 稳定的显示器标识（不要用 eDP-1 / HDMI-A-1 作为键）

连接器名（`eDP-1`、`HDMI-A-1`）是每次开机分配的，换口/换 GPU/接扩展坞后都会变，
所以配置里改用 EDID 派生的选择器：

```
$ acm-ctl list
  eDP-1      active   id=CSW1656-00000000 serial=- hash=380c4f83604eae61 name=MNG007DA5-3
             config key: hash:380c4f83604eae61
  HDMI-A-1   active   id=SKY0001-00000000 serial=0000000000 hash=4ce7d007462e9a2d name=F24B40Q
             config key: hash:4ce7d007462e9a2d
```

可用选择器（配置键与 `--output` 通用）：

| 选择器 | 含义 | 稳定性 |
|---|---|---|
| `hash:<16位十六进制>` | EDID 内容（blob）的 SHA-256 前 16 位 | **最稳**：换口/扩展坞/重启都不变 |
| `id:<PNP><产品码>-<序列号>` | 厂商 + 产品码 + EDID 序列号 | 稳定（除非同型号同序列号） |
| `serial:<值>` | EDID 序列号（十六进制）或序列号字符串 | 每台唯一 |
| `name:<显示器名>` | EDID 0xFC 显示器名（子串匹配） | 同型号会歧义 |
| `con:<连接器>` | DRM 连接器名 | **易变**，仅用于消歧 |
| 裸键 | 先按连接器、再按显示器名、再按 id 匹配 | 向后兼容 |

两个同型号显示器冲突时会明确报错并要求用 `con:` 消歧。

在 Nix 里，属性名只是标签，真正的选择器写在 `match`：

```nix
services.acm.displays = {
  internal = { match = "hash:380c4f83604eae61"; mode = "auto"; };   # 内置屏
  external = { match = "hash:4ce7d007462e9a2d"; mode = "auto"; };   # 外接屏
};
```

## Turning ACM on and off

```bash
acm-ctl status              # is it on? which applier? is the hardware really programmed? (exit 0 = on)
acm-ctl off                 # stop the daemon + clear the hardware ramp (exit 0 = cleared)
acm-ctl on                  # start the daemon + verify (exit 0 = verified)
acm-ctl status --json       # machine-readable

# temporary, without the wrapper commands:
systemctl --user stop acm   # off  (the compositor restores its default ramp)
systemctl --user start acm  # on

# permanent: edit the Nix configuration instead
#   ~/.config/home-manager/home.nix :  home.acm.enable = false;
#   /etc/nixos/configuration.nix    :  services.acm.enable = false;
```

Do **not** use `systemctl --user disable acm` or `mask acm` -- the unit file is
managed by home-manager and those commands break/are rejected; use the Nix
options or `acm-ctl off`.

## Rebuilding / re-deploying

```bash
# system side (package, /etc/acm/displays.conf, DRM access)
sudo nixos-rebuild switch

# user side (session daemon + user config)
home-manager switch -b ~/hm-backup

# check the transform is live in the display hardware
acm-ctl verify --config ~/.config/acm/displays.conf
```

## Verifying the full pipeline (needs DRM master)

While a compositor owns the displays only the gamma applier can run.  To verify
the complete `DEGAMMA_LUT + CTM + GAMMA_LUT` path, pause the session briefly on
another VT (which releases DRM master) and run the self test; it always switches
back:

```bash
sudo chvt 3
sudo acm-ctl selftest --card /dev/dri/card0   # i915 has no display attached
sudo chvt 2
```

Expected output: `degamma/gamma max deviation 0.000008 OK`, `ctm 0.000000 OK`,
`selftest: PASS`.
