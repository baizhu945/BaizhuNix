{ config, lib, pkgs, ... }:

{
  imports = [
    ./skills.nix
  ];

  home.packages = [
    pkgs.grok-build
  ];

  home.file = {
    ".grok/AGENTS.md".source = ../agent-context.md;
  };
}
