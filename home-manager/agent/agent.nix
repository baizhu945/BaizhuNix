{ config, lib, pkgs, ... }:

{
  imports = [
    ./codex/codex.nix
    ./dsh/dsh.nix
    ./pi/pi.nix
    ./cursor/cursor.nix

    ./cc-connect.nix
  ];
}
