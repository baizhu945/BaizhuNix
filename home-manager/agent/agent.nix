{ config, lib, pkgs, ... }:

{
  imports = [
    ./antigravity/antigravity.nix
    ./codex/codex.nix
    ./dsh/dsh.nix
    ./pi/pi.nix
    ./zcode/zcode.nix

    ./cc-connect.nix
  ];
}
