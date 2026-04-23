{ config, pkgs, lib, ... }:

let
  # 把背景图片复制到 nix store
  backgroundImage = pkgs.stdenvNoCC.mkDerivation {
    name = "sddm-bg-image";
    src =
      builtins.fetchurl "https://w.wallhaven.cc/full/d8/wallhaven-d8pyvo.jpg";
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out
      cp $src $out/background.png
    '';
  };

  # 生成 theme.conf.user 放到 theme 目录
   breezeThemeConf = pkgs.writeTextDir 
    "share/sddm/themes/breeze/theme.conf.user"
    ''
      [General]
      showlogo=hidden
      showClock=true
      logo=${pkgs.kdePackages.plasma-desktop}/share/sddm/themes/breeze/default-logo.svg
      type=image
      color=#1d99f3
      fontSize=10
      needsFullUserModel=false
      background = ${backgroundImage}/background.png
    '';
in
{
  environment.systemPackages = with pkgs; [
    breezeThemeConf
  ];
  services.displayManager.sddm = {
    autoNumlock = true;
    wayland = {
      enable = true;
    };
    settings = {
      General = {
        DisplayServer = "wayland";
        # 这个变量让 greeter 使用 Wayland 特定集成
        GreeterEnvironment = "QT_WAYLAND_SHELL_INTEGRATION=layer-shell,QT_SCREEN_SCALE_FACTORS=1.2";
      };
    };
  };
}
