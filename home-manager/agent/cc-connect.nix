{ config, pkgs, lib, ... }:

let
  # 用户 fork:在 upstream main 基础上包含 reasonix agent (#1281) +
  # opencode permission bridge + dsh(DeepSeek Harness)agent。
  # 当前直接从本机 fork 构建；这样工作区中的功能改动会随下一次
  # home-manager switch 进入声明式服务，不必先把提交推到 GitHub。
  # 分支 feat/dsh-agent(46541ff)= bf12b06 + jsonl 事件流/审批转发/会话标题。
  # dsh agent 通过 `dsh --profile headless --jsonl`(需 dsh.nix 的
  # headless-cc-connect.patch 支持 --session-id/--provider/--model/--reasoning-effort/--mode/--preset/--list-models/--jsonl)驱动:
  # /model、/mode 可用,confirm 模式的工具调用会以飞书审批卡片转发,
  # /preset 列出/切换空白会话的 dsh preset,/session 显示 dsh 会话标题。
  cc-connect = pkgs.buildGoModule rec {
    pname = "cc-connect";
    version = "1.5.0-fork-local";
    src = pkgs.lib.cleanSourceWith {
      src = /home/<yourusername>/Documents/cc-connect-fork;
      filter = path: type:
        let
          name = builtins.baseNameOf path;
        in
        name != ".git"
        && !(builtins.match "test_ws_[0-9a-f]+\\.json" name != null);
    };
    vendorHash = "sha256-+tHlItgdNsKS2XbNXoLALQT1unqQjomr53hkhdmyWXE=";
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
