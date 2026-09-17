{ config, pkgs, lib, ... }:

# Noctalia V5 与 dms（DankMaterialShell）由 systemd user service 托管。
# 启动条件：graphical-session.target（图形会话就绪）+ xdg-desktop-portal.service。
# 依赖的服务（supergfxd、power-profiles-daemon）均为开机自启的系统服务
# （ppd 已在 configuration.nix 中改为 wantedBy=multi-user.target），
# 因此 shell 启动时它们必然已就绪，不再需要任何等待/延时。
{
  systemd.user.services = {
    noctalia = {
      Unit = {
        Description = "Noctalia V5";
        After = [ "graphical-session.target" "xdg-desktop-portal.service" ];
        Before = [ "dms.service" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        # Noctalia 由 systemd --user 启动，不会继承 niri-config.kdl 的
        # environment{}。其 app2unit 启动的应用需要显式获得 Fcitx 变量，
        # 否则从 Noctalia 启动的 Qt/GTK 应用无法切换中文输入法。
        Environment = [
          "GTK_IM_MODULE=fcitx"
          "QT_IM_MODULE=fcitx"
          "XMODIFIERS=@im=fcitx"
          "QS_ICON_THEME=Fluent"
        ];
        # Noctalia 只设置 BlueZ 的 Powered 属性；如果 systemd-rfkill
        # 恢复了旧的软阻塞，先解除它，否则控件无法重新开启蓝牙。
        ExecStartPre = "${pkgs.util-linux}/bin/rfkill unblock bluetooth";
        ExecStart = lib.getExe config.programs.noctalia.package;
        # Before=dms.service only orders service startup. Keep that job pending
        # until V5 has created its IPC socket and acquired shared D-Bus names.
        ExecStartPost = pkgs.writeShellScript "wait-for-noctalia-v5" ''
          attempt=0
          while [ "$attempt" -lt 100 ]; do
            if ${lib.getExe config.programs.noctalia.package} msg status >/dev/null 2>&1; then
              exit 0
            fi
            attempt=$((attempt + 1))
            ${pkgs.coreutils}/bin/sleep 0.1
          done
          exit 1
        '';
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
