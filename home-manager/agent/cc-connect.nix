{ config, pkgs, lib, ... }:

let
  # 用户 fork:在 upstream main 基础上包含 reasonix agent (#1281) +
  # opencode permission bridge + dsh(DeepSeek Harness)agent。
  # 分支 feat/dsh-agent(46541ff)= bf12b06 + jsonl 事件流/审批转发/会话标题。
  # dsh agent 通过 `dsh --profile headless --jsonl`(需 dsh.nix 的
  # headless-cc-connect.patch 支持 --session-id/--model/--mode/--jsonl)驱动:
  # /model、/mode 可用,confirm 模式的工具调用会以飞书审批卡片转发,
  # /session 显示 dsh 会话标题。
  cc-connect = pkgs.buildGoModule rec {
    pname = "cc-connect";
    version = "1.5.0-fork";
    src = pkgs.fetchFromGitHub {
      owner = "<yourusername>";
      repo = "cc-connect";
      rev = "46541ff2fa3d734bc52c5f2f5e48ab05b13db2bc";
      hash = "sha256-ss124d3JeIcgWCs0f05GXNwh/+ygn6C26shVRImv09w=";
    };
    vendorHash = "sha256-pkjITb62Waok+aR8WhSAmLOSwms/denexIIVRAPV5GY=";
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
