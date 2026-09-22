# Agent Context — <yourusername>'s NixOS Development Environment

_Read this carefully. This is the guideline for operating this machine._

## Hardware Overview

| Component | Model |
|-----------|-------|
| **CPU** | Intel Core Ultra 7 255HX (20 cores, Arrow Lake-HX) |
| **GPU** | NVIDIA RTX 5060 Laptop 8GB (02:00.0, nvidia-open, CUDA 13) + Intel Arrow Lake-S iGPU + Intel NPU |
| **Memory** | 30Gi DDR5 |
| **Storage** | SAMSUNG MZVL81T0HELB 953.9G (system) · Great Wall GT745 953.9G (Windows) |
| **Network** | Intel AX210 Wi-Fi 6E · Realtek RTL8111/8168 Ethernet |

## System Information

- **OS**: NixOS 26.11pre (Zokor), kernel `linuxPackages_zen`
- **Host**: nixos · user <yourusername> (uid=1000, shell=zsh, groups: wheel, disk, networkmanager, libvirtd, kvm, docker, input, ydotool)
- **Locale**: zh_CN.UTF-8 (also en_US, ja_JP) · TZ: Asia/Shanghai
- **Desktop**: Niri 26.04 (Wayland) + KDE Plasma 6, SDDM (Wayland + kwin_wayland, Arona theme)
- **Input Method**: Fcitx5 + Mozc
- **Nix**: Lix 2.95.2

## Configuration Entry Points

### System (`/etc/nixos/`) — managed via `imports = [...]`

### Home-Manager (`~/.config/home-manager/`) — user-level

## NVIDIA GPU

- **Driver**: nvidia-open latest, CUDA 13; `hardware.nvidia.open = true`, dynamicBoost, modesetting
- **Services**: supergfxd (GPU switching), asusd, power-profiles-daemon, nvidia-powerd; nvidia-container-toolkit (Docker CUDA)
- **Kernel Params**: `nvidia-drm.modeset=1`, `nvidia_drm.fbdev=1`, `nvidia.NVreg_PreserveVideoMemoryAllocations=1`, `nvidia-modeset.hdmi_deepcolor=0`

## Declarative Configuration Guidelines

1. One `.nix` file (or dir) per module, composed via `imports = [...]`; 2-space indent; comments may be Chinese
2. `/etc/nixos/` = system-level, `~/.config/home-manager/` = user-level; `configuration.nix` / `home.nix` are the main entries
3. Use `let` bindings for reusable values: `stablePkgs`, `bilibiliPkgs`, `fenix` (see Channels above); `_module.args.stablePkgs` injects across modules
4. Modules may live in subdirs with aux scripts (e.g. `qemu-kvm/`, `rm-protection/`, `theme/`)

### 5 Mandatory Rules

1. **No non-Nix package managers** — no `apt`, `pip install`, `npm install -g`, `cargo install`; use `nix-shell -p` / `conda-shell` for ad-hoc tools (conda envs: `~/.conda/envs/{latexocr,tts}`)
2. **Never modify `/home/<yourusername>/Documents/BaizhuNix`** — read-only GitHub repo backup
3. **Prefer declarative config** — check if home-manager `home.file` can manage a file under `~/.config/` before editing it directly
4. **Reproducibility** — all `fetchTarball`/`fetchFromGitHub`/`fetchurl` must pin a fixed hash; git refs must use `rev` not branches; fill hash by empty-first then confirm
5. **Use `remove-without-permission` instead of `rm`** — the pre-installed rm wrapper (functionally identical)
6. **No flake** - only use traditional nix configs

## Search Resources

- NixOS Options: https://search.nixos.org/options?channel=unstable
- NixOS Packages: https://search.nixos.org/packages?channel=unstable
- Home-Manager Options: https://nix-community.github.io/home-manager/options.html

## cc-connect Media Sending

When the user asks to send images/files/voice through chat, **invoke the `cc-connect-send` skill** (skills dir `agent/skills/cc-connect-send`); for recurring/scheduled tasks use `cc-connect-cron` skill.
