{ config, pkgs, ... }:


let
  stableTarball =
    fetchTarball
      https://nixos.org/channels/nixos-25.11/nixexprs.tar.xz;
  stablePkgs = import stableTarball {
    config = {
      allowUnfree = true;
      allowInsecure = true;
    };
    system = pkgs.stdenv.hostPlatform.system;
  };
in
{
  imports = [
    ./niri.nix
    ./piper.nix
    ./ghostty.nix
    ./lyrics.nix
    ./mango.nix
    ./fetch.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "baizhu945";
  home.homeDirectory = "/home/baizhu945";

  home.stateVersion = "25.11"; # Please read the comment before changing.

  programs.onlyoffice.enable = true;

  home.packages = [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    pkgs.wtype
    pkgs.xdotool
    pkgs.imagemagick    
    pkgs.ekho
    pkgs.stellarium
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
    pkgs.friture
    pkgs.translate-shell
    pkgs.onedrivegui
    pkgs.ookla-speedtest
    pkgs.mission-center
    pkgs.cmatrix
    pkgs.lolcat
    pkgs.qbittorrent
    pkgs.baidupcs-go
    pkgs.texstudio
    pkgs.feishu
    pkgs.qq
    pkgs.wechat
    pkgs.qalculate-gtk
    pkgs.brave
    pkgs.google-chrome
    pkgs.firefox
    pkgs.kdePackages.discover
    pkgs.proton-vpn
    pkgs.pciutils
    pkgs.haruna
    pkgs.smplayer
    pkgs.nvtopPackages.full
    pkgs.alacritty
    pkgs.fuzzel
    pkgs.swaybg
    pkgs.noctalia-shell
    pkgs.dms-shell
    pkgs.bilibili
    pkgs.spotify
    pkgs.matugen
    pkgs.dgop
    pkgs.cava
    pkgs.wl-mirror
    pkgs.glava

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
    
    (pkgs.writeShellScriptBin "latex-ocr" ''
      #!/usr/bin/env bash
      export LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib
      latexocr
    '')

    (pkgs.writeShellScriptBin "melo-tts" ''
      #!/usr/bin/env bash
      mkdir -p ~/Music/melo
      cd ~/.conda/envs/tts
      melo "$1" "/home/baizhu945/Music/melo/$(date +%Y%m%d_%H%M%S_%3N).wav" -l zh
    '')

    (pkgs.writeShellScriptBin "mount-win" '' 
      echo "wcandxl" | sudo -S mount /dev/disk/by-partuuid/e8bba6ef-dab7-48e9-b2d6-b9b7c12da71d /mnt/Win10/EFI/
      echo "wcandxl" | sudo -S mount /dev/disk/by-partuuid/d4faa16c-2c12-433c-90df-67ce411519fd /mnt/Win10/C
      echo "wcandxl" | sudo -S mount /dev/disk/by-partuuid/1967c4ec-2813-40c2-b9f7-a420c6252c99 /mnt/Win10/D
      echo "wcandxl" | sudo -S mount /dev/disk/by-partuuid/ba12308b-873f-4bcd-bc83-c87419360ec1 /mnt/Win10/RECOVER/
    '')

    (pkgs.writeShellScriptBin "umount-win" '' 
      echo "wcandxl" | sudo -S umount /mnt/Win10/EFI/
      echo "wcandxl" | sudo -S umount /mnt/Win10/C
      echo "wcandxl" | sudo -S umount /mnt/Win10/D
      echo "wcandxl" | sudo -S umount /mnt/Win10/RECOVER/
    '')
  ];

  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    ".config/nixpkgs/config.nix".text = ''
{
  packageOverrides = pkgs: {
    nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/main.tar.gz") {
      inherit pkgs;
    };
  };
}
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

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  home.enableNixpkgsReleaseCheck = true;
}
