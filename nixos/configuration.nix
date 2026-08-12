{ config, pkgs, lib,  ... }:

let
  stableTarball =
    fetchTarball
      "https://nixos.org/channels/nixos-26.05/nixexprs.tar.xz";
  # 注：新版 nixos-unstable 的 nixpkgs.config 会通过 deferredModuleWith 泄漏
  # pkgs/top-level/config.nix 的全部默认值（含 rewriteURL = null），而 nixos-26.05
  # 已把 rewriteURL 改为 function 类型，不再接受 null，导致 nixos-rebuild 报错。
  # 因此传给 stable nixpkgs 前剔除 rewriteURL（stable 会用自身默认 lib.id）。
  stablePkgs = import stableTarball {
    config = builtins.removeAttrs config.nixpkgs.config [ "rewriteURL" ];
  };

  nix-alien-pkgs = import (
    builtins.fetchTarball "https://github.com/thiagokokada/nix-alien/tarball/master"
  ) { };

  fenix = import (
    builtins.fetchTarball "https://github.com/nix-community/fenix/archive/monthly.tar.gz"
  ) { };

  targetDpi = 144;
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix

      ./sddm-theme.nix
      ./grub-theme.nix
      ./llm-cuda.nix
      ./neovim.nix
      ./qemu-kvm/qemu-kvm.nix
      ./flatpak-pkgs.nix
      ./hifi.nix
      ./zsh.nix
      ./customized-pkgs.nix
      ./automount.nix
      ./rm-protection/rm-protection.nix
      # ./ros2.nix
      # ./g14-kernel.nix
    ];

  _module.args.stablePkgs = stablePkgs; # 将 stablePkgs 传递给其他文件
 
  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 32*1024;
    priority = 1;
  }];

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Bootloader.
  boot.loader = {
    grub = {
      enable = true;
      device = "nodev"; # "nodev" is used for UEFI
      efiSupport = true;
      useOSProber = true;
      devices = [ "nodev" ];
    };
    efi.canTouchEfiVariables = true;
  };

  # boot.kernelPackages = pkgs.linuxPackages_latest; 
  boot.kernelPackages = pkgs.linuxPackages_zen;

  hardware.cpu.intel.updateMicrocode = true;

  boot.initrd.kernelModules = [ 
    "nvidia"
    "nvidia_modeset"
  ];

  boot.kernel.sysctl = {
    "kernel.unprivileged_userns_clone" = 1;
  };

  boot.kernelParams = [ 
    "acpi_backlight=native"
    "nvidia.NVreg_TemporaryFilePath=/var/tmp"
    "nvidia-drm.modeset=1"
    "nvidia_drm.fbdev=1"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "nvidia-modeset.hdmi_deepcolor=0" # 修复 Nvidia 显卡通过 HDMI 输出不支持 2K 75Hz 的问题
  ];

  boot.extraModprobeConfig = ''
    options hid_apple fnmode=2
    options nvidia-drm color_pipeline=0
  '';

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver  # For Intel iGPU video decoding
      intel-vaapi-driver  # VA-API for Intel
      libva-vdpau-driver  # VDPAU bridge
      libvdpau-va-gl  # GL bridge
      nvidia-vaapi-driver  # NVIDIA VA-API for hardware video acceleration in apps like Kazumi
    ];
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  powerManagement.enable = true;
  services.thermald.enable = true;

  services.colord.enable = true;

  environment.variables = {
    KDE_WALLET_DISABLE = "1";
    KDE_WALLET_BACKEND = "none";
    NIXPKGS_ALLOW_UNFREE = "1";
    NIXPKGS_ALLOW_INSECURE = "1";
    fish_greeting = "";
    QS_ICON_THEME = "Fluent";
    NIXOS_OZONE_WL = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    GDK_DPI_SCALE = "1.0";
    PATH = "/usr/bin:$PATH"; # Fixed Kazumi in NixOS BUG (Caused by NixOS)
  };

  nix.package = pkgs.lixPackageSets.latest.lix;


  nixpkgs.config = {
    cudaSupport = true;
  };
  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://cache.nixos-cuda.org"
    ];
    trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Select internationalisation properties.
  i18n.defaultLocale = "zh_CN.UTF-8";
  i18n.extraLocales = [ "en_US.UTF-8/UTF-8"  "ja_JP.UTF-8/UTF-8" ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-mozc
        fcitx5-gtk
        qt6Packages.fcitx5-chinese-addons
        fcitx5-pinyin-zhwiki
        fcitx5-pinyin-moegirl
        fcitx5-mellow-themes
        kdePackages.fcitx5-qt
      ];
    };
  };

  systemd.user.services.fix-xwayland-dpi = {
    description = "Fix DPI for XWayland in Niri";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    # 等待 Niri 启动完成后运行
    after = [ "graphical-session.target" ]; 
    serviceConfig = {
      Type = "oneshot";
      # 这是一个循环检测脚本，直到 XWayland 启动并设置好 DPI
      ExecStart = pkgs.writeShellScript "fix-dpi" ''
        # 等待 DISPLAY 变量可用（最多等10秒）
        for i in {1..10}; do
          if [ -n "$DISPLAY" ]; then
            ${pkgs.xrdb}/bin/xrdb -merge <<EOF
Xft.dpi: ${toString targetDpi}
EOF
            ${pkgs.xprop}/bin/xprop -root -f _XWAYLAND_GLOBAL_OUTPUT_SCALE 32c -set _XWAYLAND_GLOBAL_OUTPUT_SCALE 2
            break
          fi
          sleep 1
        done
      '';
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # Allow installation of unfree corefonts package
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "corefonts" ];

  fonts.packages = with pkgs; [
    lxgw-wenkai
    lxgw-neoxihei
    lxgw-fusionkai
    lxgw-wenkai-tc
    lxgw-wenkai-screen

    corefonts
    vista-fonts
    vista-fonts-chs
    vista-fonts-cht
    liberation_ttf

    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    wqy_zenhei

    noto-fonts-color-emoji
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
    sarasa-gothic

    nerd-fonts.fira-code
    nerd-fonts.fira-mono
    nerd-fonts.space-mono
    nerd-fonts.droid-sans-mono
    nerd-fonts.code-new-roman
    nerd-fonts.dejavu-sans-mono
    nerd-fonts.noto
    nerd-fonts.liberation
  ];

  # Firefox 153 wrapper regression: missing GSettings schemas in wrapper.
  # Prepend schema paths to XDG_DATA_DIRS so Firefox can read
  # GTK font settings (org.gnome.desktop.interface.font-name) from any
  # launch method (desktop launcher, Niri keybind, terminal).
  # extraInit runs AFTER the auto-generated XDG_DATA_DIRS → prepends correctly.
  environment.extraInit = ''
    export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:$XDG_DATA_DIRS"
    export XDG_DATA_DIRS="${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:$XDG_DATA_DIRS"
  '';

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver = {
    enable = true;
  };

  services.desktopManager.plasma6.enable = true;
  environment.plasma6.excludePackages = with pkgs; [
    kdePackages.elisa
    kdePackages.okular
  ];

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm = {
    enable = true;
  };
  services.dbus.packages = [ pkgs.kdePackages.sddm-kcm ];

  programs.kdeconnect.enable = true;

  services.displayManager.defaultSession = lib.mkForce "niri"; # Fix defaultSession ERROR BUG
  programs.niri = {
    enable = true;
    useNautilus = false;
  };

  services.iio-niri = {
    enable = true;
    package = pkgs.iio-niri;
  };
  security.polkit = {
    enable = true;
    enablePkexecWrapper = true;
  };
  security.soteria.enable = true;

  # 使 dolphin 在其他桌面中也能访问到应用链接列表
  environment.etc."xdg/menus/applications.menu".source = 
    "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  # 为 btop 创建特权包装器
  security.wrappers.btop = {
    source = "${pkgs.btop-cuda}/bin/btop";   # 原始二进制路径
    capabilities = "cap_sys_ptrace,cap_dac_read_search+ep";  # 所需能力
    owner = "root";
    group = "root";
  };

  programs.obs-studio = {
    enable = true;
    package = (
      pkgs.obs-studio.override {
        cudaSupport = true;
      }
    );
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      waveform
      obs-pipewire-audio-capture
      obs-gstreamer
      obs-vkcapture
      obs-3d-effect
      input-overlay
    ];
  };

  xdg = {
    portal = {
      enable = true;
      wlr.enable = true;
      config = {
        niri = {
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ]; # or "kde"
        };
      };
      extraPortals = with pkgs; [
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk
        # xdg-desktop-portal-gnome
        # kdePackages.xdg-desktop-portal-kde
      ];
    };
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  services.libinput.touchpad.disableWhileTyping = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.<yourusername> = {
    isNormalUser = true;
    description = "<yourusername>";
    extraGroups = [ 
      "networkmanager" 
      "wheel" 
      "docker"
      "ydotool"
      "input"
    ];
  };

  security.sudo.extraConfig = ''
    Defaults insults
    Defaults pwfeedback
    Defaults timestamp_type=global
  '';

  services.gnome.gnome-keyring.enable = true;

  services.flatpak.enable = true;
  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    '';
  };

  services.udisks2.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.nh.enable = true;

  programs.ydotool.enable = true;

  programs.clash-verge = {
    enable = true;
    group = "wheel";
    tunMode = true;
    serviceMode = true;
    package = stablePkgs.clash-verge-rev;
  };
 
  # Automatically creates a loader in /lib/* to avoid patching stuff
  # To disable it temporarily use
  # unset NIX_LD
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      # Needed by latexocr
      libxkbfile krb5 brotli libxcb-cursor stdenv.cc.cc zlib fuse3 icu nss openssl curl expat wayland libglvnd libxcb-wm      libxcb-image     libxcb-keysyms  libxcb-render-util libxcb-cursor   libx11 libxcursor libxext libxi libxrender libxtst libxkbcommon fontconfig freetype dbus glib libpng libjpeg

      #Needed by Kazumi
      harfbuzz webkitgtk_4_1 libsoup_3 libepoxy libayatana-indicator libXv 
      libayatana-appindicator ayatana-ido gnutls libunwind libarchive pulseaudio

      # List by default
      zlib zstd stdenv.cc.cc curl openssl attr libssh bzip2 libxml2 acl libsodium util-linux xz systemd
      
      # Someone's additions
      libxcomposite libxtst libxrandr libxext libx11 libxfixes libGL libva 
      pipewire libxcb libxdamage libxshmfence libxxf86vm libelf

      # Required
      glib gtk2

      # Inspired by steam
      # https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/st/steam/package.nix#L36-L85
      networkmanager vulkan-loader libgbm libdrm libxcrypt coreutils pciutils zenity
      # glibc_multi.bin # Seems to cause issue in ARM
      
      # # Without these it silently fails
      libxinerama libxcursor libxrender libxscrnsaver libxi libsm libice 
      nspr nss cups libcap SDL2 libusb1 dbus-glib ffmpeg
      # Only libraries are needed from those two
      libudev0-shim
      
      # needed to run unity
      gtk3      icu      libnotify      gsettings-desktop-schemas
      
      # Verified games requirements
      libxt libxmu libogg libvorbis SDL SDL2_image glew_1_10 libidn tbb
      # Other things from runtime
      flac freeglut libjpeg libpng libpng12 libsamplerate libmikmod libtheora 
      libtiff pixman speex SDL_image SDL_ttf SDL_mixer SDL2_ttf SDL2_mixer 
      libappindicator-gtk2 libdbusmenu-gtk2 libindicator-gtk2 libcaca libcanberra      
      libgcrypt libvpx librsvg libxft libvdpau
      # ...
      # Some more libraries that I needed to run programs
      pango      cairo      atk      gdk-pixbuf      fontconfig      freetype      dbus      alsa-lib      expat
      # for blender
      libxkbcommon

      libxcrypt-legacy # For natron
      libGLU # For natron

      # Appimages need fuse, e.g. https://musescore.org/fr/download/musescore-x86_64.AppImage
      fuse e2fsprogs
    ];
  };  

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = [
    pkgs.libreoffice
    pkgs.sqlite
    pkgs.yad
    pkgs.python3
    pkgs.vulkan-tools
  
    pkgs.unar pkgs.rar pkgs.unzip pkgs.unrar pkgs.p7zip

    pkgs.file
    pkgs.go
    pkgs.ungoogled-chromium
    stablePkgs.blender
    pkgs.testdisk
    pkgs.ext4magic
    pkgs.mediainfo
    pkgs.yt-dlp
    pkgs.glib
    pkgs.gnumake
    pkgs.alacritty
    pkgs.xrdb
    pkgs.xprop
    pkgs.hw-probe
    pkgs.efibootmgr
    pkgs.gcc
    pkgs.libva-utils
    pkgs.brightnessctl
    pkgs.mesa-demos
    pkgs.wlr-randr
    pkgs.portaudio
    pkgs.sox
    pkgs.python314Packages.huggingface-hub
    pkgs.jq
    pkgs.lsd
    pkgs.lsof
    pkgs.evtest
    pkgs.conda
    pkgs.baobab
    pkgs.showmethekey
    pkgs.libnotify
    pkgs.tree
    pkgs.friture
    pkgs.btop-cuda
    pkgs.wget
    pkgs.gh
    pkgs.audacious
    pkgs.audacious-plugins
    pkgs.binutils
    pkgs.nirius
    pkgs.chameleos
    pkgs.networkmanagerapplet
    
    pkgs.vulnix pkgs.nix-init pkgs.nurl pkgs.noogle-search nix-alien-pkgs.nix-alien pkgs.nix-index pkgs.nix-prefetch pkgs.nix-prefetch-hg pkgs.nix-prefetch-svn pkgs.nix-prefetch-git pkgs.nix-prefetch-cvs pkgs.nix-prefetch-bzr pkgs.nix-prefetch-pijul pkgs.nix-prefetch-darcs pkgs.nix-prefetch-github pkgs.nix-prefetch-fossil pkgs.nix-prefetch-docker pkgs.nix-prefetch-scripts

    fenix.complete.toolchain
    pkgs.psmisc
    pkgs.wl-clipboard
    pkgs.harfbuzz
    pkgs.mpv-unwrapped
    stablePkgs.app2unit
    pkgs.xwayland-satellite
    pkgs.alsa-utils
    pkgs.quickshell
    
    pkgs.fastfetch pkgs.foodfetch pkgs.gitfetch pkgs.cpufetch pkgs.gpufetch pkgs.ramfetch pkgs.onefetch
    
    pkgs.exfatprogs pkgs.ntfsprogs-plus pkgs.ntfs3g
    pkgs.nodejs
    pkgs.os-prober
    
    pkgs.kdePackages.sddm-kcm pkgs.kdePackages.kate pkgs.kdePackages.yakuake pkgs.kdePackages.layer-shell-qt pkgs.kdePackages.qttools  pkgs.kdePackages.kscreen pkgs.kdePackages.kdialog pkgs.kdePackages.plasma-sdk pkgs.kdePackages.drkonqi pkgs.kurve
    
    pkgs.thunderbird-bin
    pkgs.texlivePackages.dvipng
    pkgs.texliveFull
    pkgs.miktex
    pkgs.pwvucontrol
    pkgs.coppwr

    pkgs.wineWow64Packages.stagingFull pkgs.winetricks pkgs.wineWow64Packages.waylandFull

    (stablePkgs.lutris.override {
      extraLibraries = pkgs: [ ];
      extraPkgs = pkgs: [ ];
    })
  ];

  programs.git = {
    enable = true;
    lfs.enable = true;
  };

  programs.steam = {
    enable = true;
  };

  programs.atop = {
    enable = true;
    atopRotateTimer.enable = true;
    setuidWrapper.enable = true;
    atopService.enable = true;
    atopacctService.enable = true;
    atopgpu.enable = true;
    netatop.enable = true;
  };

  services.asusd.enable = true;
  services.supergfxd.enable = true;
  services.power-profiles-daemon.enable = true;
  # ppd 默认仅 D-Bus 懒激活（Type=dbus），开机早期激活超时(>25s)导致 noctalia/dms 启动时
  # PowerProfiles 初始化失败、插件异常；改为开机自启，保证 shell 启动时它已就绪
  systemd.services.power-profiles-daemon.wantedBy = [ "multi-user.target" ];

  networking.firewall.enable = false;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia-container-toolkit.enable = true;
  hardware.nvidia = {
    open = true;
    nvidiaSettings = true;
    dynamicBoost.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    modesetting.enable = true;
    powerManagement.enable = true;
  };

  programs.gpu-screen-recorder.enable = true;

  # In /etc/nixos/configuration.nix
  virtualisation.docker = {
    enable = true;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
