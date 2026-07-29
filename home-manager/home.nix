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
    ./tts/tts.nix
    ./ghostty/ghostty.nix
    ./lyrics/lyrics.nix
    ./theme/theme.nix
    ./yazi.nix
    ./unar/unar.nix
    ./waybar/waybar.nix
    ./showmethekey/showmethekey.nix
    ./opencode/opencode.nix
    ./mouse-trail/mouse-trail.nix
    # ./noctalia-v5.nix
    # ./caelestia.nix
    ./latex-ocr.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "<yourusername>";
  home.homeDirectory = "/home/<yourusername>";

  home.stateVersion = "26.11"; # Please read the comment before changing.

  nixpkgs.config.cudaSupport = true;

  nixpkgs.overlays = [
    (final: prev: {
      onnxruntime = prev.onnxruntime.override { cudaSupport = false; };
      blender = prev.blender.override { cudaSupport = false; };
    })
  ];

  programs.onlyoffice.enable = true;

  programs.firefox = {
    enable = true;
    package = stablePkgs.firefox;
  };

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
    pkgs.blender
    stablePkgs.sage
    pkgs.octaveFull
    pkgs.maxima
    pkgs.kdePackages.cantor
    pkgs.seahorse
    stablePkgs.krita
    pkgs.kdePackages.kdenlive
    pkgs.gnome-calendar
    pkgs.mpvpaper
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
    pkgs.wechat
    stablePkgs.qalculate-gtk
    pkgs.brave
    pkgs.google-chrome
    pkgs.kdePackages.discover
    pkgs.proton-vpn
    pkgs.pciutils
    pkgs.haruna
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
      # markitdown  # temporarily disabled: depends on broken pandas-stubs tests
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

    (pkgs.writeShellScriptBin "git-update" ''
      cd ~/Documents/BaizhuNix
      remove-without-permission -r nixos
      remove-without-permission n\&d.7z
      cd ~/Documents/BaizhuNix/home-manager
      find . -maxdepth 1 -not -name ".git" -exec remove-without-permission -rf {} +

      cd ~/Documents/BaizhuNix
     
      cp -r ~/.config/home-manager/ ~/Documents/BaizhuNix/
      cp -r ~/.config/noctalia/ ~/Documents/BaizhuNix/
      cp -r ~/.config/DankMaterialShell/ ~/Documents/BaizhuNix/
      cp -r /etc/nixos/ ~/Documents/BaizhuNix/

      shopt -s nullglob
      for dir in DankMaterialShell/plugins/*; do
          [ -d "$dir" ] || continue
          remove-without-permission -rf "$dir/.git"
          git rm -r --cached --ignore-unmatch "$dir"
      done

      find . -path "./README.md" -prune -o -path "./.git" -prune -o -path "./.gitmodules" -prune -o -type f -name "*" -exec sed -i 's/<yourusername>/<yourusername>/g' {} +
      find . -path "./README.md" -prune -o -path "./.git" -prune -o -path "./.gitmodules" -prune -o -type f -name "*" -exec sed -i 's/<yourpassword>/<yourpassword>/g' {} +

      7z a -o{~/Documents/BaizhuNix} n\&d.7z noctalia/ DankMaterialShell

      remove-without-permission -r noctalia/
      remove-without-permission -r  DankMaterialShell/
      
      git status
    '')

    (pkgs.writeShellScriptBin "mount-win" '' 
      echo "<yourpassword>" | sudo -S mount /dev/disk/by-uuid/241F-8E2D /mnt/Windows/EFI/
      echo "<yourpassword>" | sudo -S mount /dev/disk/by-uuid/545C43E35C43BF0C /mnt/Windows/C
      echo "<yourpassword>" | sudo -S mount /dev/disk/by-uuid/24C073F9C073CF92 /mnt/Windows/D
      echo "<yourpassword>" | sudo -S mount /dev/disk/by-uuid/000EA90D0EA8FCB2 /mnt/Windows/RECOVER/
      echo "<yourpassword>" | sudo -S chown -R <yourusername> /mnt/Windows/C
      echo "<yourpassword>" | sudo -S chown -R <yourusername> /mnt/Windows/D
    '')

    (pkgs.writeShellScriptBin "umount-win" '' 
      echo "<yourpassword>" | sudo -S umount /mnt/Windows/EFI/
      echo "<yourpassword>" | sudo -S umount /mnt/Windows/C
      echo "<yourpassword>" | sudo -S umount /mnt/Windows/D
      echo "<yourpassword>" | sudo -S umount /mnt/Windows/RECOVER/
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
