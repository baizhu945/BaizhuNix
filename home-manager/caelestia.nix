{ config, pkgs, lib, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;

  shellSrc = pkgs.fetchFromGitHub {
    owner  = "caelestia-dots";
    repo   = "shell";
    rev    = "v2.1.0";
    hash   = "sha256-WrpwsIpM836FEZrsiQ3OAnvSYT/9Oq0Luicil5rHSOw=";
  };

  cliSrc = pkgs.fetchFromGitHub {
    owner  = "caelestia-dots";
    repo   = "cli";
    rev    = "d2aaa733bebe5feec6cc44173a5d10c7e4e09a17";
    hash   = "sha256-PpiT7xNxRbgwid42rPGQJnLZYpyPaqwPAqLwYl7O3U8=";
  };

  m3shapesSrc = pkgs.fetchFromGitHub {
    owner  = "soramanew";
    repo   = "m3shapes";
    rev    = "bdc327b29f95394a732baf3c9b19658ba23755b6";
    hash   = "sha256-kfHyzZaPHgqZML48OA+5JwBOsLdQJ2ci/aGPShvUB4Y=";
  };

  quickshellSrc = builtins.fetchTree {
    type    = "git";
    url     = "https://git.outfoxxed.me/outfoxxed/quickshell";
    rev     = "4df562dfb2475a9057f0f33a8db75808efad8670";
    narHash = "sha256-cFG5vnmjJcZRVCSUaqQLOdwkX6iqF6bY8IvvmBSGSRs=";
  };

  quickshell = pkgs.callPackage "${quickshellSrc}/default.nix" { };

  caelestia-cli = pkgs.callPackage "${cliSrc}/default.nix" {
    rev = cliSrc.rev;
    caelestia-shell = null;
    withShell = false;
  };

  caelestia-shell-pkg = pkgs.callPackage "${shellSrc}/nix/default.nix" {
    inherit quickshell;
    rev = shellSrc.rev;
    m3shapes = m3shapesSrc;
    caelestia-cli = caelestia-cli;
    withCli = true;
  };
in {
  home.packages = [ caelestia-shell-pkg caelestia-cli ];
}
