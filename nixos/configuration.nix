{ config, pkgs, lib,  ... }:

let
  stableTarball =
    fetchTarball
      https://nixos.org/channels/nixos-25.11/nixexprs.tar.xz;
  stablePkgs = import stableTarball {
    config = config.nixpkgs.config;
  };

  nix-alien-pkgs = import (
    builtins.fetchTarball "https://github.com/thiagokokada/nix-alien/tarball/master"
  ) { };

  # 定义内核版本和 Hash
  customKernel = (pkgs.linuxKernel.kernels.linux_xanmod.override {
    argsOverride = rec {
      version = "6.18.20";
      suffix = "xanmod1"; # 根据 Xanmod 习惯，通常会有这个后缀
      modDirVersion = "${version}-${suffix}";
      src = pkgs.fetchFromGitLab {
        owner = "xanmod";
        repo = "linux";
        rev = "${version}-${suffix}";
        sha256 = "sha256-CVwMRXmDq+vmepTs9Aja7+xJztz2my6Z5AZrUk3VoOA="; 
      };
    };
  });
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix

      ./sddm-theme.nix
      ./grub-theme.nix
      ./llm-cuda.nix
      ./neovim.nix
      ./qemu-kvm.nix
      ./flatpak-pkgs.nix
      #./waydroid.nix
      ./hifi.nix
      ./zsh.nix
      ./customized-pkgs.nix
      ./rust.nix
    ];

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

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackagesFor customKernel;

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
  ];

  # 修复3108T的默认F媒体键且无法修改的问题（部分国产机械键盘可能模拟的是Apple键盘协议）
  boot.extraModprobeConfig = ''
    options hid_apple fnmode=2
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
    HandleLidSwitch = "hibernate";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  powerManagement.enable = true;
  services.thermald.enable = true;

  environment.variables = {
    KDE_WALLET_DISABLE = "1";
    KDE_WALLET_BACKEND = "none";
    NIXPKGS_ALLOW_UNFREE = "1";
    NIXPKGS_ALLOW_INSECURE = "1";
    fish_greeting = "";
    QS_ICON_THEME = "Fluent";
    NIXOS_OZONE_WL = "1";
  };

  nix.settings = {
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
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
      qt6Packages.fcitx5-chinese-addons
    ];
  };

  # Allow installation of unfree corefonts package
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "corefonts" ];

  fonts.packages = with pkgs; [
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
    maple-mono.CN
    maple-mono.NF-CN
    maple-mono.NL-CN
    maple-mono.Normal-CN

    nerd-fonts.fira-code
    nerd-fonts.fira-mono
    nerd-fonts.space-mono
    nerd-fonts.droid-sans-mono
    nerd-fonts.code-new-roman
    nerd-fonts.dejavu-sans-mono
    nerd-fonts.noto
    nerd-fonts.liberation
    nerd-fonts.hack
  ];

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
  services.xserver.enable = true;

  services.desktopManager.plasma6.enable = true;
  environment.plasma6.excludePackages = with pkgs; [
    kdePackages.elisa
    kdePackages.kwallet
    kdePackages.kwallet-pam
    kdePackages.kwalletmanager
    kdePackages.okular
  ];

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm = {
    enable = true;
    theme = "breeze";
  };
  services.dbus.packages = [ pkgs.kdePackages.sddm-kcm ];

  programs.kdeconnect.enable = true;

  programs.niri = {
    enable = true;
    useNautilus = false;
    package = pkgs.niri;
  };
  services.iio-niri = {
    enable = true;
    package = pkgs.iio-niri;
  };
  security.polkit = {
    enable = true;
    debug = true;
  };
  security.soteria.enable = true;

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
      obs-backgroundremoval
      obs-pipewire-audio-capture
      obs-gstreamer
      obs-vkcapture
      obs-3d-effect
      input-overlay
    ];
  };

  xdg = {
    portal = {
      config = {
        niri = {
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ]; # or "kde"
        };
      };
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk
        xdg-desktop-portal-gnome
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
  users.users.baizhu945 = {
    isNormalUser = true;
    description = "baizhu945";
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

  # Allow unfree packages
  nixpkgs.config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
  };

  programs.appimage.enable = true;
  programs.appimage.binfmt = true;

  programs.direnv.enable = true; # 通过创建.envrc文件就可以在进入某个文件夹时自动加载环境变量

  programs.ydotool.enable = true;

  programs.clash-verge = {
    enable = true;
    group = "wheel";
    tunMode = true;
    serviceMode = true;
  };

  # Automatically creates a loader in /lib/* to avoid patching stuff
  # To disable it temporarily use
  # unset NIX_LD
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      # Needed by latexocr
      libxkbfile krb5 brotli

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
      gnome2.GConf nspr nss cups libcap SDL2 libusb1 dbus-glib ffmpeg
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
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.

    pkgs.lsd
    pkgs.lsof
    pkgs.evtest
    pkgs.conda
    pkgs.baobab
    pkgs.showmethekey
    pkgs.libnotify
    pkgs.tree
    pkgs.friture
    pkgs.zed-editor
    pkgs.btop-cuda
    pkgs.wget
    pkgs.audacious
    pkgs.audacious-plugins
    pkgs.binutils
    pkgs.piper-tts
    pkgs.ffmpeg-full
    pkgs.rustdesk-flutter
    pkgs.nirius
    pkgs.chameleos
    pkgs.networkmanagerapplet
    nix-alien-pkgs.nix-alien
    pkgs.nix-index
    pkgs.nix-prefetch
    pkgs.nix-prefetch-hg
    pkgs.nix-prefetch-svn
    pkgs.nix-prefetch-git
    pkgs.nix-prefetch-cvs
    pkgs.nix-prefetch-bzr
    pkgs.nix-prefetch-pijul
    pkgs.nix-prefetch-darcs
    pkgs.nix-prefetch-github
    pkgs.nix-prefetch-fossil
    pkgs.nix-prefetch-docker
    pkgs.nix-prefetch-scripts
    pkgs.psmisc
    pkgs.wl-clipboard
    pkgs.harfbuzz
    pkgs.winePackages.waylandFull 
    pkgs.unzip
    pkgs.unrar
    pkgs.mpv-unwrapped
    pkgs.app2unit
    pkgs.xwayland-satellite
    pkgs.alsa-utils
    pkgs.quickshell
    pkgs.fastfetch
    pkgs.exfatprogs
    pkgs.nodejs
    pkgs.git
    pkgs.vscode
    pkgs.os-prober
    pkgs.kdePackages.sddm-kcm
    pkgs.kdePackages.kate
    pkgs.kdePackages.yakuake
    pkgs.kdePackages.layer-shell-qt
    pkgs.kdePackages.qttools
    pkgs.thunderbird
    pkgs.kurve
    pkgs.texlivePackages.dvipng
    pkgs.texliveFull
    pkgs.miktex
    pkgs.pwvucontrol
    pkgs.coppwr

    (pkgs.lutris.override {
      # List of additional system libraries
      extraLibraries = pkgs: [ ];
      # List of additional system packages    
      extraPkgs = pkgs: [ ];
    })
  ];

  programs.steam = {
    enable = true;
  };

  services.asusd = {
    enable = true;
    package = pkgs.asusctl;
  };
  services.supergfxd.enable = true;
  services.power-profiles-daemon.enable = true;

  nixpkgs.overlays = with pkgs; [
    (self: super: {
      mpv-unwrapped = super.mpv-unwrapped.override {
        ffmpeg = ffmpeg-full;
      };
    })
  ];

  networking.firewall.enable = false;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.open = true;  # see the note above
  hardware.nvidia.nvidiaSettings = true;
  hardware.nvidia.dynamicBoost.enable = true;
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
    version = "590.48.01";
    # 64位驱动 Hash
    sha256_64bit = "sha256-ueL4BpN4FDHMh/TNKRCeEz3Oy1ClDWto1LO/LWlr1ok=";
    # AArch64 驱动 Hash
    sha256_aarch64 = "sha256-2AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    # 开源内核模块 Hash
    openSha256 = "sha256-hECHfguzwduEfPo5pCDjWE/MjtRDhINVr4b1awFdP44=";
    # 设置程序 Hash
    settingsSha256 = "sha256-NWsqUciPa4f1ZX6f0By3yScz3pqKJV1ei9GvOF8qIEE=";
    # 持久化服务 Hash
    persistencedSha256 = "sha256-5AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };


  hardware.nvidia.prime = {
    intelBusId = "PCI:0@0:2:0";
    nvidiaBusId = "PCI:2@0:0:0";
  };

  hardware.nvidia.modesetting.enable = true;
  hardware.nvidia.powerManagement.enable = true;
  programs.atop.atopgpu.enable = true;

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
