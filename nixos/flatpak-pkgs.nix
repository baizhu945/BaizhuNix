{ config, pkgs, lib,  ... }:

let
  nix-flatpak = builtins.fetchTarball {
    url = "https://github.com/gmodena/nix-flatpak/archive/main.tar.gz";
  };
in
{
  imports = [
    # HomeManager users should import `${nix-flatpak}/modules/home-manager.nix`
    "${nix-flatpak}/modules/nixos.nix"
  ];

  environment.systemPackages = with pkgs; [
    nix-flatpak
  ];

  # Configure nix-flatpak
  services.flatpak = {
    packages = [
      "io.github.Predidit.Kazumi"
      "org.geogebra.GeoGebra"
      "com.gopeed.Gopeed"
    ];
  };
}
