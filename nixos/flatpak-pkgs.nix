{ config, pkgs, lib,  ... }:

let
  nix-flatpak = builtins.fetchTarball {
    url = "https://github.com/gmodena/nix-flatpak/archive/main.tar.gz";
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
      "io.github.Predidit.Kazumi"
      "com.gopeed.Gopeed"
      "cn.feishu.Feishu"
    ];
  };

  # Provide missing libsndio.so.7 for Kazumi Flatpak
  # The GNOME 50 runtime does not include libsndio, but Kazumi >=2.2.4 requires it.
  # Must copy (not symlink) because Flatpak sandbox cannot resolve symlinks to /nix/store.
  system.activationScripts.flatpak-kazumi-libs = {
    text = ''
      mkdir -p /var/lib/flatpak-extra-libs
      cp -f ${pkgs.sndio}/lib/libsndio.so.7 /var/lib/flatpak-extra-libs/libsndio.so.7
      # Grant sandbox access to the extra libs directory and add it to LD_LIBRARY_PATH
      ${pkgs.flatpak}/bin/flatpak override --system --filesystem=/var/lib/flatpak-extra-libs io.github.Predidit.Kazumi
      ${pkgs.flatpak}/bin/flatpak override --system --env=LD_LIBRARY_PATH=/var/lib/flatpak-extra-libs io.github.Predidit.Kazumi
    '';
    deps = [ ];
  };

  # Update flatpak to latest version on every rebuild
  system.activationScripts.flatpak-update = {
    text = ''
      ${pkgs.flatpak}/bin/flatpak update --noninteractive 2>&1 || true
    '';
    deps = [ ];
  };
}
