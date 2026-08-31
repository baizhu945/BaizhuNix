{ config, pkgs, libs, ... }:

{
  imports = [
    ./skills.nix
  ];

  home.packages = [ pkgs.qwen-code ];

  home.file = {
    ".qwen/QWEN.md".source = ../agent-context.md;
  };
}
