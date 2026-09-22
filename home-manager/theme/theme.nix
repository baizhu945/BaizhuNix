{ config, pkgs, lib, ... }:

let
  # 将 Noctalia V5 壁纸主色同步给 Waybar 歌词与鼠标拖尾。
  colorSyncScript = builtins.readFile ./noctalia-color-sync.py;
  noctaliaColorSync = pkgs.writeText "noctalia-color-sync.py" colorSyncScript;
  syncBinRawScript = builtins.readFile ./wallpaper-theme-sync.sh;
  syncBinScript = builtins.replaceStrings ["@noctaliaColorSync@"] ["${noctaliaColorSync}"] syncBinRawScript;
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
        Description = "Sync Noctalia V5 wallpaper palette integrations";
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
