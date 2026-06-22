{ config, pkgs, lib, ... }:
let
  backgroundImage = pkgs.stdenvNoCC.mkDerivation {
    name = "sddm-bg-image";
    src = builtins.fetchurl "https://w.wallhaven.cc/full/d8/wallhaven-d8pyvo.jpg";
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out
      cp $src $out/background.jpg
    '';
  };

  # 打包整个 arona 主题，并在构建时注入壁纸路径
  aronaTheme = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "arona-sddm-login";
    version = "unstable";

    src = pkgs.fetchFromGitHub {
      owner = "Machillka";
      repo = "arona-sddm-login";
      rev = "f5337106b60bf7f3bbf337c64dd8da42deee5307"; 
      hash = "sha256-fGUq7JhbZpMlUd3BStI4U95OjTny7b9DOQSCmFQjo8E="; 
    };

    installPhase = ''
      # 创建目标目录，名字必须和主题名一致，SDDM 按目录名识别主题
      mkdir -p $out/share/sddm/themes/arona-sddm-login
      cp -r . $out/share/sddm/themes/arona-sddm-login/

      sed -i 's|ScreenWidth\s*=.*|ScreenWidth=2560|' \
      $out/share/sddm/themes/arona-sddm-login/theme.conf

      sed -i 's|ScreenHeight\s*=.*|ScreenHeight=1600|' \
      $out/share/sddm/themes/arona-sddm-login/theme.conf

      sed -i "s|Background\s*=.*|Background = ${backgroundImage}/background.jpg|" \
      $out/share/sddm/themes/arona-sddm-login/theme.conf

      sed -i 's|HeaderText\s*=.*|HeaderText = "Hatsune Miku desu !"|' \
      $out/share/sddm/themes/arona-sddm-login/theme.conf

      sed -i 's|DateFormat\s*=.*|DateFormat = "MMMM d , dddd"|' \
      $out/share/sddm/themes/arona-sddm-login/theme.conf
    '';
  };

  sddmCompositorWrapper = pkgs.writeShellScript "sddm-compositor-wrapper" ''
    ${pkgs.kdePackages.kwin}/bin/kwin_wayland "$@" &
    KWIN_PID=$!
  
    COUNT=0
    while [ $COUNT -lt 30 ]; do
      if [ -S "''${XDG_RUNTIME_DIR:-/run/sddm}/wayland-0" ]; then break; fi
      sleep 0.5; COUNT=$((COUNT + 1))
    done
    sleep 1
  
    echo "=== 执行 enable 之前 ===" | ${pkgs.systemd}/bin/systemd-cat -t sddm-diag
    ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -o 2>&1 \
      | ${pkgs.systemd}/bin/systemd-cat -t sddm-diag
  
    ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor \
      output.619f2da5-2847-4b22-ad99-d13f98cb6768.enable \
      output.619f2da5-2847-4b22-ad99-d13f98cb6768.mode.4 \
      output.619f2da5-2847-4b22-ad99-d13f98cb6768.position.-1600,0 \
      output.333960d2-01ea-45bc-bf4d-efe0e158916b.position.0,0 \
      2>&1 | ${pkgs.systemd}/bin/systemd-cat -t sddm-compositor-wrapper
    sleep 1
  
    echo "=== 执行 enable 之后 ===" | ${pkgs.systemd}/bin/systemd-cat -t sddm-diag
    ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -o 2>&1 \
      | ${pkgs.systemd}/bin/systemd-cat -t sddm-diag
  
    wait "$KWIN_PID"
  '';
in
{
  environment.systemPackages = [ aronaTheme ];

  services.displayManager.sddm = {
    enable = true;
    theme = "arona-sddm-login";

    autoNumlock = true;
    wayland = {
      enable = true;
    };
    settings = {
      General = {
        DisplayServer = "wayland";
        GreeterEnvironment = "QT_WAYLAND_SHELL_INTEGRATION=layer-shell,QT_SCREEN_SCALE_FACTORS=1.2";
      };
      Wayland = {
        CompositorCommand = "${sddmCompositorWrapper}";
      };
    };
  };

}
