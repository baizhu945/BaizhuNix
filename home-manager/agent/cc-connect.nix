{ config, pkgs, lib, ... }:

let
  # 用户 fork:在 upstream main 基础上包含 reasonix agent (#1281) +
  # opencode permission bridge(71cd028/b9673a5)。旧 v1.4.1 无 reasonix agent。
  # commit b9673a5 与 fork 的 feat/opencode-permission-bridge 分支 HEAD 一致。
  cc-connect = pkgs.buildGoModule rec {
    pname = "cc-connect";
    version = "1.5.0-fork";
    # fork 分支 feat/opencode-permission-bridge（含 pi agent、reasonix、opencode 权限桥接）
    # 1c9c6b9 = 0728e4e + fix(pi): models-store.json 回退（已提交上游 PR，见下）
    src = pkgs.fetchFromGitHub {
      owner = "<yourusername>";
      repo = "cc-connect";
      rev = "d9a1e120a631e75b4bb53da796aafdbf20f12f16";
      hash = "sha256-/19b/56HdwDf4gxql9MiNPcjMuRDv88kLBcAd7YOp0A=";
    };
    vendorHash = "sha256-j5o5fhhPNw8VY7mhDkNzdzulowaqH5Yghpkk5Ap4RUQ=";
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
