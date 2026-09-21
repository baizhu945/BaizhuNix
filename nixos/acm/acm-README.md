# acm — an ACM-equivalent for Linux

Automatic colour management for a Linux desktop, built on the colour maths that
was reverse-engineered from Windows 11's ACM (`docs/` in the parent project) and
wired into the Linux display stack. Everything is declaratively configured with
Nix and reproducible.

```
app content (sRGB / P3 / Rec.2020 / scRGB)
        │
        │  SourceDeGamma           (acm engine, 4096-entry 1D LUT)
        ▼
     linear light
        │
        │  Matrix (content primaries → panel primaries, Bradford-adapted so that
        │  content white lands on the panel's own white; colour temperature and
        │  luminance scaling folded in)              (3×3, s31.32 for KMS)
        ▼
     panel-linear
        │
        │  TargetReGamma + Adjustment1DLUT (panel gamma from EDID/ICC, extra
        │  gamma, brightness, black level, SDR reference-white scale)
        ▼
   display pipeline ──┬── KMS atomic:  DEGAMMA_LUT → CTM → GAMMA_LUT   (full ACM parity)
                      └── Wayland:     compositor ramp (wlr-gamma-control,
                                       programmed into the CRTC's GAMMA_LUT)
```

This is the same structure Windows' ACM uses (`COLORSPACE_TRANSFORM_MATRIX_V2`:
degamma 1D LUT → 3×3 matrix in CIEXYZ → regamma 1D LUT), reused verbatim from the
reverse-engineering results — including the recovered DWM gamma tables, whose
values match the Windows binaries byte for byte (verified by the test suite).

## Components

| path | purpose |
|---|---|
| `src/acm-ctl.cpp` | CLI + session daemon; `on`/`off`/`status` drive the daemon and verify the hardware, `list` prints the stable per-display identifiers, plus `capabilities`, `compute`, `apply`, `verify`, `reset`, `selftest`, `daemon` |
| `docs/acm-ctl.1` | man page (installed to `share/man/man1`) |
| `src/transform.{hpp,cpp}` | ACM-equivalent transform construction (degamma LUT, matrix, regamma + adjustment) |
| `src/edid.{hpp,cpp}` | EDID parsing (primaries, white point, gamma) + ICC profile input |
| `src/drm.{hpp,cpp}` | DRM/KMS backend: capability probing, kernel ABI blob encoding, atomic apply/readback, `MasterSession` |
| `src/gamma_wl.{hpp,cpp}` | Wayland `zwlr_gamma_control_v1` client (works under Niri/KWin/wlroots) |
| `src/config.{hpp,cpp}` | the declarative display configuration format |
| `tests/test_linux.cpp` | 73 unit checks incl. Windows-parity and kernel-ABI tests |
| `nix/package.nix` | the reproducible Nix derivation (build-time `ctest`) |

The colour engine itself (`../src/`, ~10 kLOC of verified maths) is shared with
the Windows reverse-engineering study and linked in by the build.

## Quick start

```bash
nix-shell -p cmake gcc pkg-config libdrm wayland wayland-scanner wlr-protocols   # dev shell
cmake -S . -B build && cmake --build build -j
./build/test_linux ..                    # 73 checks
./build/acm-ctl list                     # connected displays + stable config keys
./build/acm-ctl status                   # is ACM on? (exit 0 = on and verified)
./build/acm-ctl off                      # turn it off, clear the hardware ramp
./build/acm-ctl on                       # turn it back on, verify
./build/acm-ctl capabilities             # what this machine can program
./build/acm-ctl compute --output eDP-1   # the transform that would be applied
./build/acm-ctl apply --config ~/.config/acm/displays.conf --mode gamma --hold 10
./build/acm-ctl verify  --config ~/.config/acm/displays.conf
```

## Declarative configuration (Nix)

**System level** — `/etc/nixos/acm/{package.nix,module.nix}`, imported from
`configuration.nix`:

```nix
imports = [ ./acm/module.nix ];
services.acm = {
  enable = true;
  user = "<yourusername>";
  displays = {
    "eDP-1"   = { mode = "auto"; };
    "HDMI-A-1" = { mode = "auto"; };
  };
};
```

installs `acm-ctl`, writes `/etc/acm/displays.conf`, grants DRM access
(`video` group) and can run a **system** daemon (`systemService = true`) for
KMS-only sessions.

**User level** — `~/.config/home-manager/acm.nix`, imported from `home.nix`:

```nix
imports = [ ./acm.nix ];
home.acm = {
  enable = true;
  displays = {
    "eDP-1" = { };
    "HDMI-A-1" = { gamma = 1.05; temperatureEnabled = true; temperature = 6000; };
  };
};
```

writes `~/.config/acm/displays.conf` and a **systemd user service** (`acm.service`)
that starts with the graphical session and keeps the transform applied.

Per-display options: `enable`, `mode` (`auto`/`gamma`/`kms`), `profile` (ICC path;
`null` derives the profile from the panel EDID), `content`
(`sRGB`/`DisplayP3`/`Rec2020`/`scRGB`), `brightness`, `black`, `gamma`,
`temperature`, `temperatureEnabled`, `sdrWhite`.

## Stable display identifiers (do not key on "HDMI-A-1")

DRM connector names such as `eDP-1` or `HDMI-A-1` are assigned at boot and can
change (different port, GPU switch, dock, re-plug), so they must not be used as
the identity of a display.  `acm-ctl list` prints what to use instead, derived
from the panel's EDID:

```
$ acm-ctl list
connected displays (connector names are volatile; use the suggested key):
  eDP-1      active   id=CSW1656-00000000 serial=- hash=380c4f83604eae61 name=MNG007DA5-3
             config key: hash:380c4f83604eae61        currently configured as 'hash:380c4f83604eae61'
  HDMI-A-1   active   id=SKY0001-00000000 serial=0000000000 hash=4ce7d007462e9a2d name=F24B40Q
             config key: hash:4ce7d007462e9a2d        currently configured as 'hash:4ce7d007462e9a2d'
```

Selectors accepted anywhere a display is named (configuration keys, `--output`):

| selector | meaning | stability |
|---|---|---|
| `hash:<16 hex>` | SHA-256 of the EDID blob (first 16 hex digits) | most stable — survives connector changes, docking, port swaps |
| `id:<PNP><PROD>-<SERIAL>` | manufacturer + product code + EDID serial number | stable unless two units share a serial |
| `serial:<value>` | EDID serial number (hex) or the serial-string descriptor | stable per unit |
| `name:<monitor name>` | the EDID monitor-name descriptor (substring match) | stable for a given model (ambiguous with two identical panels) |
| `con:<connector>` | DRM connector name, e.g. `con:HDMI-A-1` | **volatile** — kept for disambiguation |
| bare key | connector first, then monitor name, then id (backwards compatible) | — |

Ambiguity (two identical panels) is reported explicitly and must be
disambiguated with `con:`:

```
$ acm-ctl verify --config /tmp/sim.conf
con:HDMI-A-9             SKIP  no connected display matches 'con:HDMI-A-9'
hash:380c4f83604eae61    OK    eDP-1      GAMMA_LUT size=1024, max deviation 0.00005 (0.01/255)
```

In Nix the attribute name is a free label and `match` carries the selector:

```nix
home.acm.displays = {
  internal = { match = "hash:380c4f83604eae61"; };              # 内置屏
  external = { match = "hash:4ce7d007462e9a2d";                 # 外接屏
               gamma = 1.05; temperatureEnabled = true; temperature = 6000; };
};
```

## Turning it on and off

| | command | effect |
|---|---|---|
| temporary | `systemctl --user stop acm` / `start acm` | stops/starts the session daemon (the compositor resets the ramp on stop) |
| | `acm-ctl off` / `acm-ctl on` | same, plus an explicit hardware verification of the result (exit 0 = success) |
| permanent | `home.acm.enable = false;` in `~/.config/home-manager/home.nix` | removes the user daemon + config (`home-manager switch`) |
| | `services.acm.enable = false;` in `/etc/nixos/configuration.nix` | removes the package / system config (`sudo nixos-rebuild switch`) |
| per display | `home.acm.displays."HDMI-A-1".enable = false;` | disables ACM for one output only |
| check | `acm-ctl status` / `acm-ctl status --json` | is it on, which applier, is the hardware really programmed |

`acm-ctl status` exits 0 when every configured display is verified in hardware and
1 when it is off or mismatched, so it can be used in scripts.  Do **not** use
`systemctl --user disable acm` or `mask` — those conflict with the
home-manager-managed unit file; change the Nix configuration instead.

## Appliers: what each one can do

| | KMS atomic (`mode = "kms"`) | Wayland gamma (`mode = "gamma"`) |
|---|---|---|
| degamma 1D LUT | ✔ (129/1024 entries, 16 bit) | ✖ |
| 3×3 colour matrix / gamut mapping | ✔ (`CTM`, s31.32 sign-magnitude) | ✖ (only the neutral axis) |
| regamma 1D LUT | ✔ (1024 entries) | ✔ (compositor ramp → CRTC `GAMMA_LUT`) |
| white point / colour temperature | ✔ exact | ✔ on the neutral axis |
| brightness, black level, SDR white | ✔ | ✔ |
| requires DRM master | ✔ (no compositor owns the display) | ✖ (the compositor programs it) |

`acm-ctl compute` prints both error metrics, so the limitation is measurable:
`neutral axis` error is what the gamma applier reproduces exactly (≈0.01/255),
`RGB cube` error is what a per-channel ramp cannot express (≈0 on an sRGB panel,
up to 114/255 on a wide-gamut panel). For wide-gamut panels the KMS path (or the
monitor's own sRGB preset) is needed for correct gamut mapping.

## Verification (what was actually proven on this machine)

1. **Live transform on both panels.** Niri implements
   `zwlr_gamma_control_manager_v1` and programs the CRTC `GAMMA_LUT`
   (`src/backend/tty.rs: gamma_props.set_gamma(...)`), so the daemon's ramp lands
   in the display hardware:

   ```
   $ acm-ctl verify --config ~/.config/acm/displays.conf
   eDP-1      OK  hardware GAMMA_LUT size=1024, max deviation 0.00005 (0.01/255)
   HDMI-A-1   OK  hardware GAMMA_LUT size=1024, max deviation 0.00005 (0.01/255)
   ```

   Falsification test: stopping the daemon removes the ramp and `verify` then
   **fails** (exit 1), so the check is meaningful and not vacuous.

2. **Full pipeline (DEGAMMA_LUT + CTM + GAMMA_LUT)** — programmed with a real
   DRM atomic commit while holding master, then read back:

   ```
   $ sudo acm-ctl selftest --card /dev/dri/card0     # i915, no display attached
   selftest: using /dev/dri/card0
     degamma  size=129   max deviation 0.000008 OK
     gamma    size=1024  max deviation 0.000008 OK
     ctm      max deviation 0.000000 OK
   selftest: PASS
   ```

   (Run with the session paused on another VT, which releases DRM master;
   `scripts`-free helper in the deployment notes below.)

3. **Windows parity.** The engine's gamma tables are compared against Microsoft's
   own `dwmcore.dll` data: **256/256 entries bit-identical, max 1 ULP**; the sRGB
   EOTF/scRGB↔sRGB formulas and the BT.709→BT.2020 matrix are the ones recovered
   from the Windows shaders.

4. **Reproducibility.** `nix-build nix/package.nix` twice yields the *same*
   store path; the derivation runs the full test suite at build time
   (`doCheck = true`, `ctest` → `acmlin_tests Passed`), and the source trees are
   pinned by content (`builtins.path`).

## Platform notes (this machine)

* Displays are driven by `card1` (nvidia-drm): `eDP-1` (internal, 2560×1600@165)
  and `HDMI-A-1` (external, wide gamut). The Intel iGPU (`card0`) is idle; `vkms`
  (`card2`) can be loaded for testing.
* nvidia-drm exposes the full colour pipeline: `DEGAMMA_LUT` (1024),
  `CTM`, `GAMMA_LUT` (1024) plus `NV_CRTC_REGAMMA_TF` (enum incl. **PQ**) and
  `NV_CRTC_REGAMMA_LUT` — so HDR-style transfer functions are available to a
  compositor that can program them.
* Because any atomic commit needs DRM master (verified: `EACCES` otherwise), the
  session daemon uses the compositor ramp path; the KMS applier takes over
  automatically whenever `acm-ctl` runs where it can hold master
  (`mode = "auto"` probes it).

## Limits / not implemented

* The Wayland path cannot express the 3×3 matrix (protocol limitation), so
  wide-gamut gamut mapping needs the KMS path.
* Compositors do not delegate the CTM/degamma properties; a fully integrated
  in-compositor ACM would require compositor support (e.g. per-output transform
  in Niri/KWin) — the engine and appliers here are ready for it.
* No measurement-based calibration (a colorimeter-generated ICC profile can be
  supplied via `profile`, but no calibration loop is included).
* HDR/PQ output is exposed by the driver (`NV_CRTC_REGAMMA_TF`) but only used when
  the display is configured for it; SDR ACM is the implemented default.
