{ lib, pkgs, config, ... }:

{
  programs.cursor = {
    enable = true;
    package = pkgs.cursor-cli;
  };

  home.file = {
    ".cursor/rules/AGENTS.md".source = ../agent-context.md;
  };
}
