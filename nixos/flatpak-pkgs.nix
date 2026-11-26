{ config, pkgs, lib,  ... }:

let
  nix-flatpak = builtins.fetchTarball {
    url = "https://github.com/gmodena/nix-flatpak/archive/20d42f0ee98c9fe9f85e8d1de474f1409ed10d05.tar.gz";
    sha256 = "sha256-0H8jDwR4Kegb3heaTrH1ftbgKfZVDT8JE+46uXxDy/Q=";
  };
in
{
  imports = [
    "${nix-flatpak}/modules/nixos.nix"
  ];

  environment.systemPackages = with pkgs; [
    nix-flatpak
    flatpak-xdg-utils
    sndio  # libsndio.so.7 for Kazumi (missing from GNOME runtime)
  ];

  # Configure nix-flatpak
  services.flatpak = {
    packages = [
      # {
        # appId = "io.github.Predidit.Kazumi";
        # Kazumi 2.4.4 bundles Flutter 3.50.0, whose NVIDIA shader compositor
        # renders only a quarter of the window (flutter/flutter#195885).
        # Keep the previous working build until Kazumi includes fix #196083.
        # commit = "311b70d9f6a21f295a0f490b51f218f1a0777b8de1f2ef4d4e3e2d8feaa5205c";
      # }
      "io.github.Predidit.Kazumi"
      # "com.gopeed.Gopeed"
      "cn.feishu.Feishu"
    ];
  };

  # Update unmasked Flatpaks to latest version on every rebuild.
  # system.activationScripts.flatpak-update = {
    # text = ''
      # ${pkgs.flatpak}/bin/flatpak update --noninteractive 2>&1 || true
    # '';
    # deps = [ "flatpak-kazumi-pin" ];
  # };
}
