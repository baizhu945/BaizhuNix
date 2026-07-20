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
hardware-configuration # Auto-generated, do not modify
customized-pkgs.nix   # FreeCAD, Ventoy, GParted wrappers
llm-cuda.nix          # Ollama, CUDA
qemu-kvm.nix          # libvirt, QEMU, binfmt (aarch64/riscv64)
neovim.nix            # nixvim config
zsh.nix              # ZSH + Oh-My-Zsh
rm-protection    # rm safety wrapper folder
hifi.nix             # MPD, PipeWire high sample rate
automount.nix        # Windows partition auto-mount
sddm-theme.nix       # SDDM theme Arona
grub-theme.nix       # GRUB wallpaper
flatpak-pkgs.nix     # Flatpak + nix-flatpak
g14-kernel.nix       # linux-g14 kernel (commented out)
```

### Home-Manager (`~/.config/home-manager/`)
```
home.nix              # Main entry
opencode/opencode.nix # OpenCode config
ghostty/ghostty.nix   # Terminal emulator
waybar/waybar.nix     # Status bar (lyrics display)
yazi.nix             # File manager
piper.nix            # Piper TTS
noctalia-v5.nix      # Custom Noctalia Shell
theme/theme.nix      # Wallpaper theme sync
script/              # niri-config.kdl, fastfetch-config.jsonc, battery-monitor.sh
```

### Nix Channels
- `nixpkgs` → nixpkgs-unstable
- `home-manager` → master
- Config references `nixos-26.05` as stablePkgs
- Some packages come from `nixpkgs-unstable` (llm-cuda.nix)

## NVIDIA GPU

- **Driver**: nvidia-open (latest), CUDA 13
- **Container**: nvidia-container-toolkit enabled, Docker CUDA support
- **Service**: supergfxd (GPU switching), asusd (ROG control)
- **Video Acceleration**: nvidia-vaapi-driver
- **OBS**: CUDA acceleration, background removal plugins

## Important Services

| Service | Status | Purpose |
|---------|--------|---------|
| Ollama | enabled (cuda) | Local LLM (gemma4:12b, deepseek-ocr) |
| Docker | enabled | Containerized development |
| libvirtd | enabled | KVM/QEMU virtualization |
| Flatpak | enabled | Flathub apps (Kazumi, Feishu, etc.) |
| MPD | enabled | High-fidelity audio playback (DX5 II DAC) |
| PipeWire | enabled | Audio (supports 768kHz) |
| Waybar | enabled | Top bar lyrics display |
| Noctalia-shell | enabled | Wayland Shell |
| DankMaterialShell | enabled | Desktop widgets |
| cc-connect | enabled | Connection service |

## Software Ecosystem

### Development
- **Editor**: Neovim (nixvim, cyberdream theme), VS Code, Kate
- **Shell**: ZSH + Oh-My-Zsh (re5et theme)
- **Git**: git + gh + git-lfs + direnv
- **Build**: gcc, make, cmake (nix-ld), Rust (fenix toolchain)
- **LaTeX**: TeX Live Full + MikTeX
- **Math**: Sage, Octave, Maxima, Cantor (KDE)

### Multimedia
- **Video**: mpv (ffmpeg-full), Haruna, SMPlayer, bilibili
- **Audio**: Audacious, Spotify, melo-tts, piper-tts, sox, friture
- **Graphics**: Blender, Krita, GIMP, Kdenlive, ImageMagick
- **Recording**: OBS Studio (CUDA), gpu-screen-recorder

### Daily Applications
- **Browser**: Firefox, Google Chrome, Brave
- **Communication**: QQ, WeChat, Feishu (Flatpak)
- **Office**: OnlyOffice, LibreOffice, Qalculate
- **Cloud Storage**: onedrivegui, BaiduPCS-Go
- **Download**: qBittorrent, Gopeed, Ghost Downloader 3

## Declarative Configuration Guidelines

### Architecture Conventions
1. One `.nix` file per module, composed via `imports = [...]`
2. `/etc/nixos/` manages system-level config, `~/.config/home-manager/` manages user-level config
3. `configuration.nix` and `home.nix` handle imports only; actual logic goes into submodules
4. Use `let` bindings for reusable values (e.g. stablePkgs, unstablePkgs)
5. 2-space indentation; comments may use Chinese

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
