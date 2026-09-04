{ config, pkgs, lib, ... }:

let
  # Reproducible snapshot of the dsh PR branch plus its follow-up fixes.
  # Keep both rev and hash pinned; the source is the pushed fork revision,
  # not the local working tree.
  # dsh agent 通过 `dsh --profile headless --jsonl`(需 dsh.nix 的
  # headless-cc-connect.patch 支持 --session-id/--provider/--model/--reasoning-effort/--mode/--preset/--list-models/--jsonl)驱动:
  # /model、/mode 可用,confirm 模式的工具调用会以飞书审批卡片转发,
  # /preset 列出/切换空白会话的 dsh preset,/session 显示 dsh 会话标题。
  cc-connect = pkgs.buildGoModule rec {
    pname = "cc-connect";
    version = "1.5.0-dsh-pr1682-fixes";
    src = pkgs.lib.cleanSourceWith {
      src = pkgs.fetchFromGitHub {
        owner = "<yourusername>";
        repo = "cc-connect";
        rev = "c31042d16700a9976c51b0ffad20781ed068a1f3";
        hash = "sha256-wPdUo/oGVk9KunwPEf62MuViorwYr6LQ+S+F9/zRYoY=";
      };
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
