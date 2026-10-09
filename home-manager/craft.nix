{ lib, config, pkgs, ... }:

{
  imports = [
    ./craft/cadcraft.nix
    ./craft/filmcraft.nix
    ./craft/photocraft.nix
    ./craft/soundcraft.nix
    ./craft/wordcraft.nix
  ];
}
