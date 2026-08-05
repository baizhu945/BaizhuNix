{ config, pkgs, lib, ... }:

# noctalia-shell 与 dms（DankMaterialShell）由 systemd user service 托管。
# 启动条件：graphical-session.target（图形会话就绪）+ xdg-desktop-portal.service。
# 依赖的服务（supergfxd、power-profiles-daemon）均为开机自启的系统服务
# （ppd 已在 configuration.nix 中改为 wantedBy=multi-user.target），
# 因此 shell 启动时它们必然已就绪，不再需要任何等待/延时。
{
  systemd.user.services = {
    noctalia-shell = {
      Unit = {
        Description = "Noctalia shell (quickshell)";
        After = [ "graphical-session.target" "xdg-desktop-portal.service" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.noctalia-shell}/bin/noctalia-shell";
        Restart = "on-failure";
        RestartSec = "3s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    dms = {
      Unit = {
        Description = "DankMaterialShell (quickshell)";
        After = [ "graphical-session.target" "xdg-desktop-portal.service" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.dms-shell}/bin/dms run";
        Restart = "on-failure";
        RestartSec = "3s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
