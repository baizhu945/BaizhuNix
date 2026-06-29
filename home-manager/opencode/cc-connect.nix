{ config, pkgs, lib, ... }:

let
  cc-connect = pkgs.buildGoModule rec {
    pname = "cc-connect";
    version = "1.4.1";
    src = pkgs.fetchFromGitHub {
      owner = "chenhg5";
      repo = "cc-connect";
      rev = "v${version}";
      hash = "sha256-Spm1OB0z7+E0JvWOtBAtUrRHiEc+aPjBYVHy0zc7ww4=";
    };
    vendorHash = "sha256-FgiCP4XuFv1/VQjtZ/rr6Qb5F9BqmzX5ptegKlW5Cv8=";
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
