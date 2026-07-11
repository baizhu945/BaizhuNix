# Agent Context — <yourusername> 的 NixOS 开发环境

_请仔细阅读以下内容。这是你操作本机的准则。_

---

## 硬件概览

| 组件 | 型号 |
|------|------|
| **CPU** | Intel Core Ultra 7 255HX (20核, Arrow Lake-HX) |
| **iGPU** | Intel Arrow Lake-S [Intel Graphics] (PCI:0@0:2:0) |
| **dGPU** | NVIDIA GeForce RTX 5060 Laptop GPU (PCI:2@0:0:0), 8GB VRAM |
| **NPU** | Intel Arrow Lake NPU |
| **内存** | 30Gi (DDR5) |
| **存储** | SAMSUNG MZVL81T0HELB-00BTW 953.9G (系统, WWN: eui.0025384551b7d1d8), Great Wall GT745 1TB 953.9G (Windows, WWN: nvme.1e4b-...-00000001) |
| **显示器** | 内屏: MNG007DA5-3 2560x1600@165Hz, 外接: SKYDATA F24B40Q 2560x1440@75Hz (HDMI) |
| **WiFi** | Intel AX210 (Wi-Fi 6E) |
| **有线** | Realtek RTL8111/8168 |
| **音频** | Intel 800 Series ACE (Audio Context Engine), 外置 DAC: DX5 II (USB) |

## 系统信息

- **OS**: NixOS 26.11pre (Zokor), 内核 `linuxPackages_zen`
- **Hostname**: nixos
- **User**: <yourusername> (uid=1000, shell=zsh)
- **Locale**: zh_CN.UTF-8 (额外: en_US.UTF-8, ja_JP.UTF-8)
- **时区**: Asia/Shanghai
- **桌面**: Niri (Wayland) + KDE Plasma 6 (SDDM)
- **输入法**: Fcitx5 + Mozc
- **Lix**: 2.95.2 (Nix 兼容实现)

## 分区与挂载

```
SAMSUNG MZVL81T0HELB-00BTW (WWN: eui.0025384551b7d1d8) — 系统盘:
  ├─ UUID=C7DB-CE0E      /boot      (vfat, 1G)
  ├─ UUID=54b5887e-...   /          (ext4, 919G, /nix/store)
  └─ UUID=394f6ea6-...   [SWAP]     (33.8G)

Great Wall GT745 1TB (WWN: nvme.1e4b-...-00000001) — Windows 盘:
  ├─ UUID=241F-8E2D          /mnt/Windows/EFI     (vfat, 100M)
  ├─ UUID=545C43E35C43BF0C   /mnt/Windows/C       (ntfs3, 441G)
  ├─ UUID=24C073F9C073CF92   /mnt/Windows/D       (ntfs3, 512G)
  └─ UUID=000EA90D0EA8FCB2   /mnt/Windows/RECOVER (ntfs3, 583M)

外置盘: /mnt/T7_Shield — exfat (UUID=601F-0929)
```

## 关键配置入口

### NixOS 系统配置 (`/etc/nixos/`)
```
configuration.nix      # 主入口，imports 导入所有模块
hardware-configuration # 自动生成，勿修改
customized-pkgs.nix   # FreeCAD, Ventoy, GParted 等包装
llm-cuda.nix          # Ollama, CUDA
qemu-kvm.nix          # libvirt, QEMU, binfmt (aarch64/riscv64)
neovim.nix            # nixvim 配置
zsh.nix              # ZSH + Oh-My-Zsh
rm-protection.nix    # rm 安全包装
hifi.nix             # MPD, PipeWire 高采样率
automount.nix        # Windows 分区自动挂载
sddm-theme.nix       # SDDM 主题 Arona
grub-theme.nix       # GRUB 壁纸
flatpak-pkgs.nix     # Flatpak + nix-flatpak
g14-kernel.nix       # linux-g14 内核 (已注释)
```

### Home-Manager (`~/.config/home-manager/`)
```
home.nix              # 主入口
opencode/opencode.nix # OpenCode 配置
ghostty/ghostty.nix   # 终端
waybar/waybar.nix     # 状态栏 (歌词显示)
yazi.nix             # 文件管理器
piper.nix            # Piper TTS
noctalia-v5.nix      # 自定义 Noctalia Shell
theme/theme.nix      # 壁纸主题同步
script/              # niri-config.kdl, fastfetch-config.jsonc, battery-monitor.sh
```

### Nix 频道
- `nixpkgs` → nixpkgs-unstable
- `home-manager` → master
- 配置中引用了 `nixos-26.05` 作为 stablePkgs
- 部分包从 `nixpkgs-unstable` 获取 (llm-cuda.nix)

## NVIDIA GPU

- **驱动**: nvidia-open (最新), CUDA 13
- **容器**: nvidia-container-toolkit 启用, Docker CUDA 支持
- **服务**: supergfxd (GPU 切换), asusd (ROG 控制)
- **视频加速**: nvidia-vaapi-driver
- **OBS**: CUDA 加速, 支持背景移除等插件

## 重要服务

| 服务 | 状态 | 用途 |
|------|------|------|
| Ollama | 启用 (cuda) | 本地 LLM (gemma4:12b, deepseek-ocr) |
| Docker | 启用 | 容器化开发 |
| libvirtd | 启用 | KVM/QEMU 虚拟化 |
| Flatpak | 启用 | Flathub 应用 (Kazumi, Feishu 等) |
| MPD | 启用 | 高保真音频播放 (DX5 II DAC) |
| PipeWire | 启用 | 音频 (支持 768kHz) |
| Waybar | 启用 | 顶部歌词状态栏 |
| Noctalia-shell | 启用 | Wayland Shell |
| DankMaterialShell | 启用 | 桌面小组件 |
| cc-connect | 启用 | 连接服务 |

## 软件生态

### 开发工具
- **编辑器**: Neovim (nixvim, cyberdream 主题), VS Code, Kate
- **Shell**: ZSH + Oh-My-Zsh (re5et 主题)
- **Git**: git + gh + git-lfs + direnv
- **构建**: gcc, make, cmake (nix-ld), Rust (fenix toolchain)
- **LaTeX**: TeX Live Full + MikTeX
- **数学**: Sage, Octave, Maxima, Cantor (KDE)

### 多媒体
- **视频**: mpv (ffmpeg-full), Haruna, SMPlayer, bilibili (B站)
- **音频**: Audacious, Spotify, melo-tts, piper-tts, sox, friture
- **图像**: Blender, Krita, GIMP, Kdenlive, ImageMagick
- **录屏**: OBS Studio (CUDA), gpu-screen-recorder

### 日常应用
- **浏览器**: Firefox, Google Chrome, Brave
- **通讯**: QQ, WeChat, Feishu (Flatpak)
- **办公**: OnlyOffice, LibreOffice, Qalculate
- **网盘**: onedrivegui, BaiduPCS-Go
- **下载**: qBittorrent, Gopeed, Ghost Downloader 3

## 声明式配置准则

### 架构约定
1. 每个模块一个 `.nix` 文件，通过 `imports = [...]` 组合
2. `/etc/nixos/` 管系统级配置，`~/.config/home-manager/` 管用户级配置
3. `configuration.nix` 和 `home.nix` 只做 import 编排，具体逻辑拆入子模块
4. 使用 `let` 绑定可复用的值（如 stablePkgs、unstablePkgs）
5. 2 空格缩进，注释可以用中文

### Nix 写法模式
```nix
# 引用稳定频道
let
  stableTarball = fetchTarball "https://nixos.org/channels/nixos-26.05/nixexprs.tar.xz";
  stablePkgs = import stableTarball { config = config.nixpkgs.config; };
in

# 声明式地启用程序
programs.ghostty = {
  enable = true;
  settings = {
    font-family = "Noto Sans Mono CJK HK";
  };
};

# 安装包
environment.systemPackages = with pkgs; [ git gh vscode ];
# 或者
home.packages = with pkgs; [ blender krita ];
```

### 必须遵守的 5 条规则

1. **不要用非 Nix 的包管理器安装程序**
   - 禁止使用 `apt`, `pip install`, `npm install -g`, `cargo install` 等
   - 临时工具使用 `conda-shell` 或 `nix-shell`（如 `nix-shell -p hello --run "hello"`）
   - conda 环境: `~/.conda/envs/` 下有 `latexocr` 和 `tts` 两个环境

2. **不要更改 `/home/<yourusername>/Documents/BaizhuNix` 文件夹**
   - 这是 READ-ONLY 的 GitHub 仓库备份目录

3. **优先通过 `~/.config/home-manager/` 声明式修改用户配置**
   - 修改 `~/.config/` 下的文件之前，先检查是否能通过 `home-manager` 的 `home.file` 声明式解决
   - 只有无法声明式配置的内容才直接修改 `~/.config/` 目录下的文件

4. **保证 nix 代码可复现**
   - 所有 `fetchTarball`、`fetchFromGitHub`、`fetchurl` 必须指定固定 hash
   - 所有 Git 引用必须指定 `rev` (commit hash)，不使用分支名
   - 引用打包文件必须先写空 hash 获取 `sha256`，再填入确认

5. **使用 `remove-without-permission` 替代 `rm`**
   - `remove-without-permission` 是系统预装的 `rm` 包装，功能等同于 `rm`
   - 示例: `remove-without-permission -r some-directory`

## 搜索资源

- NixOS 选项: https://search.nixos.org/options?channel=unstable
- NixOS 包: https://search.nixos.org/packages?channel=unstable
- Home-Manager 选项: https://nix-community.github.io/home-manager/options.html
- Noctalia: https://github.com/noctalia-dev/noctalia
