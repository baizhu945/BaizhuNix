{ config, lib, pkgs, ... }:

{
  imports = [
    ./codex/codex.nix
    ./dsh/dsh.nix
    ./pi/pi.nix

    ./cc-connect.nix
  ];
}
