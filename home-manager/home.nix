{ config, pkgs, ... }:


let
  stableTarball =
    fetchTarball
      "https://nixos.org/channels/nixos-26.05/nixexprs.tar.xz";
  stablePkgs = import stableTarball {
    config = {
      allowUnfree = true;
      allowInsecure = true;
    };
    system = pkgs.stdenv.hostPlatform.system;
  };

  bilibiliTarball =
    fetchTarball
      "https://github.com/NixOS/nixpkgs/archive/cdb16195ed783fcd8681120639d305b789169b97.tar.gz";
  bilibiliPkgs = import bilibiliTarball {
    config = {
      allowUnfree = true;
      allowInsecure = true;
    };
    system = pkgs.stdenv.hostPlatform.system;
  };
in
{
  imports = [
    ./tts/tts-qwen.nix
    ./ghostty/ghostty.nix
    ./lyrics/lyrics.nix
    ./theme/theme.nix
    ./yazi.nix
    ./unar/unar.nix
    ./waybar/waybar.nix
    ./showmethekey/showmethekey.nix
    ./agent/pi/pi.nix
    ./agent/mmx/mmx.nix
    ./agent/dsh/dsh.nix
    ./agent/codex/codex.nix
    ./mouse-trail/mouse-trail.nix
    # ./noctalia-v5.nix
    ./latex-ocr.nix
    ./shell-services.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "<yourusername>";
  home.homeDirectory = "/home/<yourusername>";

  home.stateVersion = "26.11"; # Please read the comment before changing.

  nixpkgs.config.cudaSupport = true;

  programs.onlyoffice.enable = true;


  nixpkgs.overlays = with pkgs; [
    # nixpkgs 更新把 frei0r 包升到 3.2.1（CMake 构建），
    # 其 find_package(OpenCV) 在 CUDA 版 opencv 下硬性要求 CUDAToolkit/nvcc，
    # 导致构建失败（上游回归，release-25.11 仍为 2.5.1）。
    # 这里 pin 回 2.5.1（与 release-25.11 相同的表达式），
    # 与旧系统产物 drv 哈希一致，直接复用本地缓存，零编译。
    # 注意：ffmpeg-full 依赖的属性名是 frei0r（by-name 包），
    # frei0r-plugins 是别名，两个都覆盖以确保一致。
    (self: super: let
      # 注意：必须用 callPackage（而非裸 stdenv.mkDerivation）包装，
      # 新版 nixpkgs 的 override/overrideAttrs 由 callPackage/makeOverridable 注入，
      # mlt 等包会调用 frei0r.override { opencv = ...; }，裸 mkDerivation 产物没有该属性。
      frei0r-251 = super.callPackage (
        { lib, config, stdenv, fetchFromGitHub, cairo, cmake, opencv, pkg-config
        , cudaSupport ? config.cudaSupport, cudaPackages
        }:
        stdenv.mkDerivation (finalAttrs: {
          pname = "frei0r-plugins";
          version = "2.5.1";
          src = fetchFromGitHub {
            owner = "dyne";
            repo = "frei0r";
            rev = "v${finalAttrs.version}";
            hash = "sha256-3gUWvO5izOrJt+XwcNBNiLfu+iMqo4nuPbx++TYzao0=";
          };
          nativeBuildInputs = [ cmake pkg-config ];
          buildInputs = [ cairo opencv ]
            ++ lib.optionals cudaSupport [
              cudaPackages.cuda_cudart
              cudaPackages.cuda_nvcc
            ];
          postInstall = lib.optionalString stdenv.hostPlatform.isDarwin ''
            for f in $out/lib/frei0r-1/*.so* ; do
              ln -s $f "''${f%.*}.dylib"
            done
          '';
          meta = {
            homepage = "https://frei0r.dyne.org";
            description = "Minimalist, cross-platform, shared video plugins";
            license = lib.licenses.gpl2Plus;
            platforms = lib.platforms.unix;
          };
        })
      ) { };
    in {
      frei0r = frei0r-251;
      frei0r-plugins = frei0r-251;
    })
  ];

  home.packages = [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    pkgs.wlrctl
    pkgs.agent-browser
    pkgs.geogebra6
    pkgs.wtype
    pkgs.xdotool
    pkgs.imagemagick    
    pkgs.pandoc
    pkgs.pdftk
    pkgs.poppler
    pkgs.qpdf
    pkgs.ekho
    stablePkgs.localsend
    pkgs.tokei
    pkgs.kile
    pkgs.kdePackages.kmplot
    pkgs.labplot
    stablePkgs.sage
    stablePkgs.octaveFull
    pkgs.maxima
    pkgs.kdePackages.cantor
    pkgs.seahorse
    stablePkgs.krita
    stablePkgs.kdePackages.kdenlive
    pkgs.gnome-calendar
    stablePkgs.mpvpaper
    pkgs.slurp
    pkgs.grim
    pkgs.translate-shell
    pkgs.onedrivegui
    pkgs.ookla-speedtest
    pkgs.mission-center
    pkgs.cmatrix
    pkgs.lolcat
    pkgs.qbittorrent
    pkgs.baidupcs-go
    pkgs.texstudio
    pkgs.qq
    stablePkgs.qalculate-gtk
    pkgs.brave
    pkgs.google-chrome
    pkgs.kdePackages.discover
    pkgs.proton-vpn
    pkgs.pciutils
    stablePkgs.haruna
    pkgs.smplayer
    pkgs.nvtopPackages.full
    pkgs.noctalia-shell
    pkgs.dms-shell
    bilibiliPkgs.bilibili
    pkgs.spotify
    pkgs.matugen
    pkgs.dgop
    pkgs.cava
    pkgs.wl-mirror
    pkgs.glava

    (let
      pythonWithFix = pkgs.python3.override {
        packageOverrides = self: super: {
          pandas-stubs = super.pandas-stubs.overridePythonAttrs (_: {
            doCheck = false;
            doInstallCheck = false;
            pythonImportsCheck = [];
          });
        };
      };
    in pythonWithFix.withPackages (p: with p; [
      defusedxml lxml openpyxl pandas pdf2image pdfplumber
      pillow pypdf pytesseract reportlab
    ]))

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')

    (pkgs.writeShellScriptBin "nix-update" ''
      echo '<yourpassword>' | sudo -S nix-channel --update
      nix-channel --update
      echo '<yourpassword>' | sudo -S nixos-rebuild boot --upgrade
      home-manager build switch
    '')

    (pkgs.writeShellScriptBin "nix-clean" ''
      noctalia-shell ipc call toast send '{"title":"Cleaning"}'
      echo '<yourpassword>' | sudo -S nix-store --gc
      nix-store --gc
      echo '<yourpassword>' | sudo -S nix-collect-garbage --delete-old
      nix-collect-garbage --delete-old
      noctalia-shell ipc call toast send '{"title":"Clean Completed"}'
    '')

    (pkgs.writeShellScriptBin "git-update" (builtins.readFile ./script/git-update.sh))

    (pkgs.writeShellScriptBin "mount-win" '' 
      echo "<yourpassword>" | sudo -S mount /dev/disk/by-uuid/AEDB-5D56 /mnt/Windows/EFI/
      echo "<yourpassword>" | sudo -S mount /dev/disk/by-uuid/7CFAFFF4FAFFA892 /mnt/Windows/C
      echo "<yourpassword>" | sudo -S mount /dev/disk/by-uuid/00D8E718D8E70AAC /mnt/Windows/D
      echo "<yourpassword>" | sudo -S mount /dev/disk/by-uuid/8A324B9F324B8F5F /mnt/Windows/RECOVER
      echo "<yourpassword>" | sudo -S chown -R <yourusername> /mnt/Windows/C
      echo "<yourpassword>" | sudo -S chown -R <yourusername> /mnt/Windows/D
    '')

    (pkgs.writeShellScriptBin "umount-win" '' 
      echo "<yourpassword>" | sudo -S umount /mnt/Windows/EFI/
      echo "<yourpassword>" | sudo -S umount /mnt/Windows/C
      echo "<yourpassword>" | sudo -S umount /mnt/Windows/D
      echo "<yourpassword>" | sudo -S umount /mnt/Windows/RECOVER/
    '')

    (pkgs.writeShellScriptBin "deepseek-ocr" ''
      IMG=$(mktemp /tmp/deepseek-ocr-XXXXXX.png)

      grim -g "$(slurp)" "$IMG"

      if [ ! -s "$IMG" ]; then
          remove-without-permission -f "$IMG"
          exit 0
      fi

      yad \
          --progress \
          --title="OCR" \
          --text="正在识别..." \
          --pulsate \
          --no-buttons \
          --width=300 \
          --height=100 &
      YAD_PID=$!

      RESULT=$(ollama run deepseek-ocr:3b-gpu12 "$IMG\nFree OCR." 2>/dev/null)

      kill "$YAD_PID" 2>/dev/null

      remove-without-permission -f "$IMG"

      if [ -z "$RESULT" ]; then
          yad \
              --title="OCR 结果" \
              --text="OCR 识别失败，请重试。" \
              --button="关闭:0"
          ollama stop deepseek-ocr:3b-gpu12 2>/dev/null &
          exit 1
      fi

      TEXTFILE=$(mktemp /tmp/deepseek-ocr-text-XXXXXX.txt)
      echo "$RESULT" > "$TEXTFILE"

      OUTPUT=$(yad \
          --title="OCR 结果" \
          --text-info \
          --editable \
          --filename="$TEXTFILE" \
          --width=700 \
          --height=500 \
          --button="复制:0" \
          --button="关闭:1")

      RET=$?

      remove-without-permission -f "$TEXTFILE"

      if [ "$RET" -eq 0 ]; then
          echo -n "$OUTPUT" | wl-copy
      fi

      ollama stop deepseek-ocr:3b-gpu12 2>/dev/null &
    '')
  ];

  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    ".config/niri/config.kdl".source = ./script/niri-config.kdl;

    ".config/fastfetch/config.jsonc".source = ./script/fastfetch-config.jsonc;

    ".config/fcitx5/conf/classicui.conf".text = ''
      Theme=kwinblur-mellow-youlan-dark
    '';

    ".config/translate-shell/init.trans".text = ''
      {
        :engine          "bing"
      }
    '';

    ".config/xdg-desktop-portal/niri-portals.conf".text = ''
      [preferred]
      default=wlr;gtk
      org.freedesktop.impl.portal.ScreenCast=wlr
      org.freedesktop.impl.portal.Screenshot=wlr
    '';

    ".config/alacritty/alacritty.toml".text = ''
      [font]
      normal = { family = "Noto Sans Mono CJK HK", style = "Regular" }
      size = 12
      offset = { x = 0, y = 0 }
      builtin_box_drawing = true

      [scrolling]
      history = 100000

      [cursor]
      style = { shape="Beam", blinking="off" }
      thickness = 0.2
    '';

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  programs.joplin-desktop = {
    enable = true;
    sync = {
      interval = "5m";
      target = "onedrive";
    };
  };

  systemd.user.services.battery-monitor = {
    Unit = {
      Description = "Battery discharge action trigger";
      After = [ "graphical-session.target" ];
      Wants = [ "graphical-session.target" ];
    };
    Service = {
      Restart = "always";
      RestartSec = "5s";
      ExecStart =
        let
          script = pkgs.replaceVars ./script/battery-monitor.sh {
            upower   = pkgs.upower;
            grep     = pkgs.gnugrep;
            noctalia = pkgs.noctalia-shell;
            jq       = pkgs.jq;
            wlrrandr = pkgs.wlr-randr;
          };
        in
        "${pkgs.bash}/bin/bash ${script}";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  home.enableNixpkgsReleaseCheck = true;
}
