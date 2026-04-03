{ config, lib, pkgs, ... }:

{
  programs.kitty = lib.mkForce {
    enable = true;
    settings = {
      foreground = "#dddddd";
      background = "#111111";
      selection_foreground = "#111111";
      selection_background = "#333333";
      font_family = "Maple Mono Normal CN";
      font_size = 12.0;
      modify_font = "cell_height 110%"; # 行间距
      confirm_os_window_close = 0;
      dynamic_background_opacity = true;
      enable_audio_bell = false;
      mouse_hide_wait = "-1.0";
      window_padding_width = 3;
      background_blur = 20;
      cursor_shape = "beam";
      cursor_blink_interval = 0;
      cursor_trail = 1;
      cursor_trail_color = "#00bcd4";
      scrollback_lines = 20000;
    };
  };
}
