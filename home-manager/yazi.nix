{ config, lib, pkgs, ... }:

{
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    extraPackages = with pkgs; [
      mediainfo
      ripdrag
      util-linux
    ];
    settings = {
      mgr = {
        sort_by = "natural";
        sort_dir_first = true;
        sort_translit = true;
        linemode = "size";
        show_hidden = true;
        show_symlink = true;
        mouse_events = ["click" "scroll" "move" "drag"];
      };
      preview = {
        image_filter = "lanczos3";
        image_quality = 90;
      };
      input = {
        cursor_blink = false;
      };
      plugin = {
        # Needed by mediainfo plugin
        prepend_preloaders = [
          { mime = "{audio,video,image}/*"; run = "mediainfo"; }
          { mime = "application/subrip"; run = "mediainfo"; }
          { mime = "application/postscript"; run = "mediainfo"; }
          { mime = "application/illustrator"; run = "mediainfo"; }
          { mime = "application/dvb.ait"; run = "mediainfo"; }
          { mime = "application/vnd.adobe.illustrator"; run = "mediainfo"; }
          { mime = "image/x-eps"; run = "mediainfo"; }
          { mime = "application/eps"; run = "mediainfo"; }
          { url = "*.{ai,eps,ait}"; run = "mediainfo"; }
        ];
        prepend_previewers = [
          { mime = "{audio,video,image}/*"; run = "mediainfo"; }
          { mime = "application/subrip"; run = "mediainfo"; }
          { mime = "application/postscript"; run = "mediainfo"; }
          { mime = "application/illustrator"; run = "mediainfo"; }
          { mime = "application/dvb.ait"; run = "mediainfo"; }
          { mime = "application/vnd.adobe.illustrator"; run = "mediainfo"; }
          { mime = "image/x-eps"; run = "mediainfo"; }
          { mime = "application/eps"; run = "mediainfo"; }
          { url = "*.{ai,eps,ait}"; run = "mediainfo"; }
        ];
      };
      tasks = {
        image_alloc = 1073741824; # Needed by mediainfo plugin
      };
    };

    keymap = {
      mgr.prepend_keymap = [
        # Needed by drag plugin
        { on = [ "<C-d>" ]; run = "plugin drag"; desc = "Drag Files"; }

        # Needed by mount plugin
        { on = "M"; run = "plugin mount"; }
      ];
    };

    plugins = {
      drag = {
        package = pkgs.yaziPlugins.drag;
      };
      mount = {
        package = pkgs.yaziPlugins.mount;
      };
      mediainfo = {
        package = pkgs.yaziPlugins.mediainfo;
      };
    };
  };
}
