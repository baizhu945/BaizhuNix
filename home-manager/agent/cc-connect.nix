{ config, pkgs, lib, ... }:

let
  # Reproducible snapshot of the public PR branch. Keep both rev and hash
  # pinned; do not replace this with a user's local working-tree path.
  # The commit is the head of chenhg5/cc-connect#1682 via <yourusername>'s fork.
  # dsh agent 通过 `dsh --profile headless --jsonl`(需 dsh.nix 的
  # headless-cc-connect.patch 支持 --session-id/--provider/--model/--reasoning-effort/--mode/--preset/--list-models/--jsonl)驱动:
  # /model、/mode 可用,confirm 模式的工具调用会以飞书审批卡片转发,
  # /preset 列出/切换空白会话的 dsh preset,/session 显示 dsh 会话标题。
  cc-connect = pkgs.buildGoModule rec {
    pname = "cc-connect";
    version = "1.5.0-dsh-pr1682";
    src = pkgs.lib.cleanSourceWith {
      src = pkgs.fetchFromGitHub {
        owner = "<yourusername>";
        repo = "cc-connect";
        rev = "5436fca8bead04091157861b03233cf24b913c20";
        hash = "sha256-/1rXt4LUJ5H7RGZHj68twDb9lGSSbFmRaz/xjqTdc2Q=";
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
