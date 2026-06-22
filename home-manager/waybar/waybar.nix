{ lib, config, pkgs, ... }:

{
  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      targets = [ "niri-session.target" ];
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
        };
      };
    };
  };
}
