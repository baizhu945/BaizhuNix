{ config, pkgs, lib,  ... }:

let
  stableTarball =
    fetchTarball
      https://nixos.org/channels/nixos-25.11/nixexprs.tar.xz;
  stablePkgs = import stableTarball {
    config = config.nixpkgs.config;
  };

  # 把插件 tar 包声明为一个固定输出的 Nix 派生
  peazipPluginTar = pkgs.fetchurl {
    url = "https://sourceforge.net/projects/peazip/files/Resources/PeaZip%20Additional%20Formats%20Plugin/peazip-additional-formats-plugin.7.LINUX.tar";
    hash = "sha256-90q/LD2XpyyARX1t/zaZKbz9DfYZsCNdgam4L4iKPUw=";
  };
  # 创建一个合并了 peazip + 插件的新派生
  peazipWithPlugins = pkgs.runCommand "peazip-with-plugins"
    {
      nativeBuildInputs = [ pkgs.rsync ];
    }
    ''
      # 把 peazip 的整个目录树复制到输出目录
      mkdir -p $out
      rsync -a ${pkgs.peazip}/ $out/
      chmod -R u+w $out/
      # 解压插件 tar 包
      mkdir -p /tmp/peazip-plugin
      tar -xf ${peazipPluginTar} -C /tmp/peazip-plugin
      # 把插件里的二进制文件复制到 peazip 的 res 目录
      mkdir -p $out/share/peazip/res # 无这一行会因为不明原因报错
      mkdir -p $out/lib/peazip/res 
      mkdir -p $out/lib/peazip/res/bin 
      cp -r /tmp/peazip-plugin/peazip-additional-formats-plugin.7.LINUX/* $out/lib/peazip/res/bin
      chmod -R +x $out/share/peazip/res/
    '';

  # 先把包装脚本定义为一个独立变量，方便后面的 desktop item 引用路径
  freecad-wrapped = pkgs.symlinkJoin {
    name = "freecad-wrapped";
    paths = [ pkgs.freecad ];  # 或 stablePkgs.freecad
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/freecad \
        --set QT_QPA_PLATFORM xcb
      # 删除原包的 .desktop 文件，避免启动器出现两个图标
      rm -f $out/share/applications/org.freecad.FreeCAD.desktop
    '';
  };
in
{
  environment.systemPackages = with pkgs; [
    peazipWithPlugins

    # 包装后的二进制
    freecad-wrapped
    # 对应的 .desktop 文件，Exec 直接指向包装后的绝对路径
    # 使用绝对路径而非命令名，确保启动器一定调用的是包装版本
    (pkgs.makeDesktopItem {
      name = "freecad";
      desktopName = "FreeCAD";
      exec = "${freecad-wrapped}/bin/freecad %F";
      icon = "freecad";
      comment = "FreeCAD 3D CAD Modeler";
      categories = [ "Graphics" ];
    })

    (pkgs.writeShellScriptBin "gparted-wayland" ''
      exec pkexec env \
        WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
        XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        DISPLAY="$DISPLAY" \
        ${pkgs.gparted-full}/bin/gparted "$@"
    '')
    (pkgs.makeDesktopItem {
      name = "gparted-wayland";
      desktopName = "GParted";
      exec = "gparted-wayland";
      icon = "gparted";
      comment = "GParted (Wayland)";
      categories = [ "System" ];
    })
  
    (pkgs.writeShellScriptBin "ventoy-gui" ''
      ${pkgs.xauth}/bin/xauth generate "$DISPLAY" . trusted
      exec pkexec env \
        DISPLAY="$DISPLAY" \
        XAUTHORITY="$HOME/.Xauthority" \
        ${pkgs.ventoy-full-qt}/bin/ventoy-gui "$@"
    '')
    (pkgs.makeDesktopItem {
      name = "ventoy-gui";
      desktopName = "Ventoy";
      exec = "ventoy-gui";
      icon = "ventoy";
      comment = "Ventoy";
      categories = [ "System" ];
    })
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "ventoy-qt5-1.1.10"
  ];
}
