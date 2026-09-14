{ lib, config, pkgs, ... }:

{
  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      # niri-session.target is not provided by this session; use the active
      # standard graphical-session target so Waybar is service-managed.
      targets = [ "graphical-session.target" ];
      enableDebug = true;
    };

    style = builtins.readFile ./style.css;
    
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        margin-left = 0;
        margin-right = 0;
        margin-top = 10;
        exclusive = false;
        passthrough = true;
        reload_style_on_change = true;

        modules-left = [
        ];
        modules-center = [
          "custom/lyrics"
        ];
        modules-right = [
        ];

        "custom/lyrics" = {
          "exec" = "waybar-lyrics";
          "return-type" = "json";
          "escape" = true;
          "restart-interval" = 5;
        };
      };
    };
  };
}
