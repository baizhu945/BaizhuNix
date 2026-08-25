{ pkgs, lib, config, ... }:

{
  imports = [
    ./skills.nix
    ./desktop.nix
  ];

  programs.codex = {
    enable = true;
    context = ../agent-context.md;
  };
}
