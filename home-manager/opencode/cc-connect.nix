{ config, pkgs, lib, ... }:

let
  cc-connect = pkgs.buildGoModule rec {
    pname = "cc-connect";
    version = "1.3.4";
    src = pkgs.fetchFromGitHub {
      owner = "chenhg5";
      repo = "cc-connect";
      rev = "v${version}";
      hash = "sha256-O2VahCIkhJ+Rh8pNK6g+shnHQq9oiE3WEz6SizuLd5U=";
    };
    vendorHash = "sha256-WcxTCpj9epxGFm21MlMK/p/SrxKjewMhxffRHWaepHc=";
    tags = [ "no_web" ];
    doCheck = false;
    overrideModAttrs = (_: {
      GOPROXY = "https://goproxy.cn,direct";
    });
  };
in
{
  home.packages = [
    cc-connect
  ];

  systemd.user.services.cc-connect = {
    Unit = {
      Description = "cc-connect";
      After = [ "network-online.target" ];
    };
    Service = {
      ExecStart =
        "${cc-connect}/bin/cc-connect";
      Restart = "always";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
