{ config, pkgs, lib, ... }:

let
  # Python 脚本：读取 noctalia colors.json，转换为 DMS 自定义主题格式
  themeScript = builtins.readFile ./noctalia-to-dms.py;
  noctaliaToDms = pkgs.writeText "noctalia-to-dms.py" themeScript;
  #
  syncBinRawScript = builtins.readFile ./wallpaper-theme-sync.sh;
  syncBinScript = builtins.replaceStrings ["@noctaliaToDms@"] ["${noctaliaToDms}"] syncBinRawScript;
  syncBin = pkgs.writeShellApplication {
    name = "wallpaper-theme-sync";
    runtimeInputs = with pkgs; [ inotify-tools python3 jq ];
    text = syncBinScript;
  };

  notify-closer-script = builtins.readFile ./chrome-notif-closer.sh;
  notify-closer = pkgs.writeShellApplication {
    name = "niri-chrome-notif-closer";
    runtimeInputs = with pkgs; [ jq niri ];
    text = notify-closer-script;
  };
in
{
  systemd.user.services = {
    wallpaper-theme-sync = {
      Unit = {
        Description = "Sync noctalia wallpaper palette → DankMaterialShell theme";
        After  = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type       = "simple";
        ExecStart  = "${syncBin}/bin/wallpaper-theme-sync";
        Restart    = "on-failure";
        RestartSec = "3s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    niri-chrome-notif-closer = {
      Unit = {
        Description = "Auto-close Chrome notification windows in niri after 2s";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${notify-closer}/bin/niri-chrome-notif-closer";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
