# Agent Context — <yourusername>'s NixOS Development Environment

_Read this carefully. This is the guideline for operating this machine._

---

## Hardware Overview

| Component | Model |
|-----------|-------|
| **CPU** | Intel Core Ultra 7 255HX (20 cores, Arrow Lake-HX) |
| **iGPU** | Intel Arrow Lake-S [Intel Graphics] (PCI:0@0:2:0) |
| **dGPU** | NVIDIA GeForce RTX 5060 Laptop GPU (PCI:2@0:0:0), 8GB VRAM |
| **NPU** | Intel Arrow Lake NPU |
| **Memory** | 30Gi (DDR5) |
| **Storage** | SAMSUNG MZVL81T0HELB-00BTW 953.9G (system, WWN: eui.0025384551b7d1d8), Great Wall GT745 1TB 953.9G (Windows, WWN: nvme.1e4b-...-00000001) |
| **Display** | Internal: MNG007DA5-3 2560x1600@165Hz, External: SKYDATA F24B40Q 2560x1440@75Hz (HDMI) |
| **WiFi** | Intel AX210 (Wi-Fi 6E) |
| **Ethernet** | Realtek RTL8111/8168 |
| **Audio** | Intel 800 Series ACE (Audio Context Engine), External DAC: DX5 II (USB) |

## System Information

- **OS**: NixOS 26.11pre (Zokor), kernel `linuxPackages_zen`
- **Hostname**: nixos
- **User**: <yourusername> (uid=1000, shell=zsh)
- **Locale**: zh_CN.UTF-8 (also: en_US.UTF-8, ja_JP.UTF-8)
- **Timezone**: Asia/Shanghai
- **Desktop**: Niri (Wayland) + KDE Plasma 6 (SDDM)
- **Input Method**: Fcitx5 + Mozc
- **Lix**: 2.95.2 (Nix compatible implementation)

## Partition & Mount Points

```
SAMSUNG MZVL81T0HELB-00BTW (WWN: eui.0025384551b7d1d8) — System disk:
  ├─ UUID=C7DB-CE0E      /boot      (vfat, 1G)
  ├─ UUID=54b5887e-...   /          (ext4, 919G, /nix/store)
  └─ UUID=394f6ea6-...   [SWAP]     (33.8G)

Great Wall GT745 1TB (WWN: nvme.1e4b-...-00000001) — Windows disk:
  ├─ UUID=241F-8E2D          /mnt/Windows/EFI     (vfat, 100M)
  ├─ UUID=545C43E35C43BF0C   /mnt/Windows/C       (ntfs3, 441G)
  ├─ UUID=24C073F9C073CF92   /mnt/Windows/D       (ntfs3, 512G)
  └─ UUID=000EA90D0EA8FCB2   /mnt/Windows/RECOVER (ntfs3, 583M)

External: /mnt/T7_Shield — exfat (UUID=601F-0929)
```

## Key Configuration Entry Points

### NixOS System Config (`/etc/nixos/`)
```
configuration.nix      # Main entry, imports all modules
hardware-configuration.nix # Auto-generated, do not modify
customized-pkgs.nix   # FreeCAD, Ventoy, GParted, Ghost Downloader, Spectroterm
llm-cuda.nix          # Ollama CUDA, syncModels (deepseek-ocr, gemma4:12b)
qemu-kvm/             # libvirt, QEMU, binfmt, virtiofsd, OVMF
neovim.nix            # nixvim (cyberdream theme, coc-nvim, telescope, treesitter)
zsh.nix              # ZSH + Oh-My-Zsh (re5et theme, zsh-autosuggestions)
rm-protection/        # rm safety wrapper (remove-without-permission)
hifi.nix              # MPD (DX5 II DAC, DSD), PipeWire (up to 768kHz)
automount.nix         # Windows partition auto-mount + udev rules
sddm-theme.nix        # SDDM Arona theme (Wayland + kwin_wayland compositor)
grub-theme.nix        # GRUB blurred wallpaper (2560x1600)
flatpak-pkgs.nix      # nix-flatpak (Kazumi, Gopeed, Feishu)
g14-kernel.nix        # linux-g14 7.0.2 kernel (commented out, ASUS ROG patches)
```

### Home-Manager (`~/.config/home-manager/`)
```
home.nix              # Main entry (imports all submodules)
opencode/             # OpenCode config + agent context + cc-connect
ghostty/              # Ghostty terminal (custom cursor shader, Bright Lights theme)
waybar/               # Waybar (top bar with lyrics center module)
yazi.nix              # Yazi file manager (drag, mount, mediainfo plugins)
tts/                  # Multi-voice Edge TTS (zh/ja/en, speak/speak-file/speak-clip)
noctalia-v5.nix       # Noctalia shell v5 (built from source, meson+ninja)
caelestia.nix         # Caelestia shell + CLI (Material 3, built via quickshell)
theme/                # Wallpaper → DMS theme sync service + Chrome notif closer
latex-ocr.nix         # pix2tex (LaTeX OCR) with all pinned Python deps
lyrics/               # Waybar lyrics (playerctl + NetEase Cloud Music API)
mouse-trail/          # Custom Wayland mouse trail overlay (C + Wayland layer-shell)
showmethekey/         # Keystroke display toggle
unar/                 # KDE Dolphin right-click unar extract/preview service menu
script/               # niri-config.kdl, fastfetch-config.jsonc, battery-monitor.sh
```

### Nix Channels & Channelsets
- `nixpkgs` → nixpkgs-unstable (channel)
- `home-manager` → master
- `stablePkgs`: nixos-26.05 (for clash-verge, lutris, localsend, sage, krita, FreeCAD)
- `oldCudaPkgs`: pinned nixpkgs rev for older CUDA compatibility
- `bilibiliPkgs`: pinned nixpkgs rev for bilibili package
- `llm-cuda.nix` also imports from `nixpkgs-unstable` (ollama-cuda)

## NVIDIA GPU

- **Driver**: nvidia-open (latest), CUDA 13
- **Container**: nvidia-container-toolkit enabled, Docker CUDA support
- **Service**: supergfxd (GPU switching), asusd (ROG control), power-profiles-daemon
- **Video Acceleration**: nvidia-vaapi-driver, intel-media-driver, intel-vaapi-driver
- **Kernel Params**: `nvidia-drm.modeset=1`, `nvidia_drm.fbdev=1`, `nvidia.NVreg_PreserveVideoMemoryAllocations=1`
- **OBS**: CUDA acceleration, background removal, wlrobs, waveform, pipewire-audio-capture, vkcapture, 3d-effect, input-overlay

## Important Services

| Service | Status | Purpose |
|---------|--------|---------|
| Ollama | enabled (cuda) | Local LLM (gemma4:12b, deepseek-ocr, syncModels) |
| Docker | enabled | Containerized development |
| libvirtd | enabled | KVM/QEMU virtualization (virtiofsd, swtpm, nested KVM) |
| Flatpak | enabled | Flathub + nix-flatpak (Kazumi, Gopeed, Feishu) |
| MPD | enabled | High-fidelity audio playback (DX5 II DAC, DSD native) |
| PipeWire | enabled | Audio (supports up to 768kHz, resample quality 14) |
| Waybar | enabled | Top bar lyrics display (playerctl + NetEase API) |
| Noctalia-shell | enabled | Wayland Shell (v5, built from source) |
| DankMaterialShell | enabled | Desktop widgets (theme auto-synced from Noctalia) |
| cc-connect | enabled | Connection service (Go binary from home-manager) |
| Clash Verge | enabled | Proxy/VPN (tun mode, service mode, from stablePkgs) |
| SDDM | enabled | Display manager (Wayland + kwin_wayland, Arona theme) |
| GNOME Keyring | enabled | Credential storage |
| KDE Connect | enabled | Phone integration |
| atopd | enabled | Process/system monitoring (atopgpu, netatop) |
| Blueman | enabled | Bluetooth device management |
| thermald | enabled | Thermal management |
| iio-niri | enabled | Niri input/output integration |
| wallpaper-theme-sync | enabled | Auto-sync Noctalia wallpaper palette → DMS theme |

## Software Ecosystem

### Development
- **Editor**: Neovim (nixvim, cyberdream theme, coc-nvim, telescope, treesitter, ufo fold), VS Code, Kate
- **Shell**: ZSH + Oh-My-Zsh (re5et theme), Ghostty terminal (cursor_tail shader)
- **Git**: git + gh + git-lfs + direnv (nix-direnv)
- **Build**: gcc, make, cmake, binutils (nix-ld for external binaries), Rust (fenix complete toolchain)
- **Nix Tools**: nh (helper), nix-init, nurl, nix-alien, nix-index, nix-prefetch-*
- **LaTeX**: TeX Live Full + MikTeX + texstudio + kile
- **Math**: Sage, Octave, Maxima, Cantor (KDE), labplot, geogebra6, qalculate-gtk

### Multimedia
- **Video**: mpv (ffmpeg-full overlay), Haruna, SMPlayer, bilibili (from pinned pkg)
- **Audio**: Audacious, Spotify, Ekho TTS, Edge TTS (zh/ja/en, speak/speak-file/speak-clip), sox, friture
- **Graphics**: Blender, Krita, GIMP, Kdenlive, ImageMagick, stellarium
- **Recording**: OBS Studio (CUDA + plugins), gpu-screen-recorder (CUDA)

### Daily Applications
- **Browser**: Firefox, Google Chrome, Brave
- **Communication**: QQ, WeChat, Feishu (Flatpak), Thunderbird
- **Office**: OnlyOffice, LibreOffice, Qalculate, Joplin (OneDrive sync)
- **VPN/Proxy**: Clash Verge, Proton VPN
- **Cloud Storage**: onedrivegui, BaiduPCS-Go
- **Download**: qBittorrent, Gopeed (Flatpak), Ghost Downloader 3
- **Gaming**: Steam, Wine (wayland + staging), winetricks, Mangohud
- **System**: btop-cuda (cap_sys_ptrace), mission-center, baobab, ookla-speedtest, app2unit, nvtop

## Declarative Configuration Guidelines

### Architecture Conventions
1. One `.nix` file (or directory) per module, composed via `imports = [...]`
2. `/etc/nixos/` manages system-level config, `~/.config/home-manager/` manages user-level config
3. `home.nix` handles imports and lightweight inline config; `configuration.nix` handles imports + core system config (boot, graphics, desktop, fonts, etc.)
4. Some modules use subdirectories (e.g. `qemu-kvm/`, `rm-protection/`) containing the `.nix` file + auxiliary scripts
5. Use `let` bindings for reusable values: `stablePkgs` (nixos-26.05), `oldCudaPkgs`, `fenix`, `nix-alien-pkgs`, `bilibiliPkgs`
6. 2-space indentation; comments may use Chinese

### Nix Writing Patterns
```nix
# Reference stable channel
let
  stableTarball = fetchTarball "https://nixos.org/channels/nixos-26.05/nixexprs.tar.xz";
  stablePkgs = import stableTarball { config = config.nixpkgs.config; };
in

# Declaratively enable programs
programs.ghostty = {
  enable = true;
  settings = {
    font-family = "Noto Sans Mono CJK HK";
  };
};

# Install packages
environment.systemPackages = with pkgs; [ git gh vscode ];
# Or
home.packages = with pkgs; [ blender krita ];
```

### 5 Mandatory Rules

1. **Do not use non-Nix package managers**
   - Prohibited: `apt`, `pip install`, `npm install -g`, `cargo install`, etc.
   - For ad-hoc tools, use `conda-shell` or `nix-shell` (e.g. `nix-shell -p hello --run "hello"`)
   - conda environments: `~/.conda/envs/` contains `latexocr` and `tts`

2. **Do not modify `/home/<yourusername>/Documents/BaizhuNix`**
   - This is a READ-ONLY GitHub repository backup

3. **Prefer declarative configuration via `~/.config/home-manager/`**
   - Before modifying files under `~/.config/`, check if `home-manager`'s `home.file` can handle it declaratively
   - Only directly modify `~/.config/` when declarative configuration is not possible

4. **Ensure Nix code reproducibility**
   - All `fetchTarball`, `fetchFromGitHub`, `fetchurl` must specify a fixed hash
   - All Git references must use `rev` (commit hash), not branch names
   - For packaged files: write empty hash first to get `sha256`, then fill in the confirmed value

5. **Use `remove-without-permission` instead of `rm`**
   - `remove-without-permission` is the pre-installed `rm` wrapper, functionally identical to `rm`
   - Example: `remove-without-permission -r some-directory`

## Search Resources

- NixOS Options: https://search.nixos.org/options?channel=unstable
- NixOS Packages: https://search.nixos.org/packages?channel=unstable
- Home-Manager Options: https://nix-community.github.io/home-manager/options.html

---

## Skill-Driven Workflow (from addyosmani/agent-skills)

### Core Rules

- If a task matches a skill, you MUST invoke it
- Never implement directly if a skill applies
- Always follow the skill instructions exactly (do not partially apply them)

### Intent → Skill Mapping

Map user intent to skills automatically:

- Feature / new functionality → `spec-driven-development`, then `incremental-implementation`, `test-driven-development`
- Planning / breakdown → `planning-and-task-breakdown`
- Bug / failure / unexpected behavior → `debugging-and-error-recovery`
- Code review → `code-review-and-quality`
- Refactoring / simplification → `code-simplification`
- API or interface design → `api-and-interface-design`
- UI work → `frontend-ui-engineering`

### Lifecycle Mapping (Implicit Commands)

OpenCode does not support slash commands like `/spec` or `/plan`. Follow this lifecycle internally:

- DEFINE → `spec-driven-development`
- PLAN → `planning-and-task-breakdown`
- BUILD → `incremental-implementation` + `test-driven-development`
- VERIFY → `debugging-and-error-recovery`
- REVIEW → `code-review-and-quality`
- SHIP → `shipping-and-launch`

### Execution Model

For every request:

1. Determine if any skill applies (even a 1% chance)
2. Invoke the appropriate skill using the `skill` tool
3. Follow the skill workflow strictly
4. Only proceed to implementation after required steps (spec, plan, etc.) are complete

### Anti-Rationalization

The following thoughts are incorrect and must be ignored:

- "This is too small for a skill"
- "I can just quickly implement this"
- "I'll gather context first"

Correct behavior:

- Always check for and use skills first

This ensures OpenCode behaves similarly to Claude Code with full workflow enforcement.
