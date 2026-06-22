{ pkgs, ... }: 

{
  programs.ghostty = {
    enable = true;

    # Enable for whichever shell you plan to use!
    enableZshIntegration = true;

    installBatSyntax = true;
    installVimSyntax = true;

    settings = {
      cursor-style-blink = false;
      cursor-color = "#bae1e6";
      mouse-hide-while-typing = true;
      font-family = "Noto Sans Mono CJK HK";
      font-size = "12";
      theme = "Bright Lights";

      custom-shader = "~/.config/ghostty/shaders/cursor_tail.glsl";
      custom-shader-animation = "always";
    };
  };

  home.file = {
    # Thanks for https://github.com/sahaj-b/ghostty-cursor-shaders
    ".config/ghostty/shaders/cursor_tail.glsl".source = ./ghostty-cursor_tail.glsl;
  };
}
