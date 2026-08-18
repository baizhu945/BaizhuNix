{ config, pkgs, lib, stablePkgs, ... }:

let
  # 先把包装脚本定义为一个独立变量，方便后面的 desktop item 引用路径
  freecad-wrapped = pkgs.symlinkJoin {
    name = "freecad-wrapped";
    paths = [ stablePkgs.freecad ];  # 或 pkgs.freecad
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/freecad \
        --set QT_QPA_PLATFORM xcb
      # 删除原包的 .desktop 文件，避免启动器出现两个图标
      rm -f $out/share/applications/org.freecad.FreeCAD.desktop
    '';
  };

  spectroterm = pkgs.stdenv.mkDerivation {
    pname = "spectroterm";
    version = "0.7.2";
    src = pkgs.fetchurl {
      url = "https://github.com/sparklost/spectroterm/releases/download/0.7.2/spectroterm-0.7.2-linux.tar.gz";
      hash = "sha256-RnZOoGokB6aB4ujDZNRN8OmJdhHstqvYW+0xVh9SJro=";
    };
    sourceRoot = ".";  # 文件直接在压缩包根目录
    dontBuild = true;
    installPhase = ''
      install -Dm755 spectroterm $out/bin/spectroterm
    '';
    meta = with lib; {
      description = "Spectroterm terminal";
      platforms = platforms.linux;
    };
  };


  ghost-downloader = pkgs.stdenv.mkDerivation {
      pname = "ghost-downloader";
      version = "4.0.5";
      src = pkgs.fetchurl {
        url = "https://github.com/XiaoYouChR/Ghost-Downloader-3/releases/download/v4.0.5/Ghost-Downloader-v4.0.5-Linux-x86_64.tar.xz";
        hash = "sha256-4em0MIMnEnC6/Ew3hq/fxfPEqZuCvLwSheTtYqfmdBU=";
      };
      icon = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/XiaoYouChR/Ghost-Downloader-3/main/app/assets/logo.png";
        hash = "sha256-2I+2YzSLK4kzZnN/e0tsIyenFrYJXKNDpBcm34BGXsM="; 
      };
      sourceRoot = ".";
      dontBuild = true;
      dontStrip = true;
      dontPatchELF = true;
      installPhase = ''
        mkdir -p $out/lib/ghost-downloader
        cp -r . $out/lib/ghost-downloader/
        chmod +x $out/lib/ghost-downloader/Ghost-Downloader-3.bin
        mkdir -p $out/bin
        cat > $out/bin/ghost-downloader << EOF
  #!/bin/sh
  cd "$out/lib/ghost-downloader"
  exec ./Ghost-Downloader-3.bin "\$@"
  EOF
        chmod +x $out/bin/ghost-downloader
  
        install -Dm644 $icon $out/share/icons/hicolor/256x256/apps/ghost-downloader.png
  
        mkdir -p $out/share/applications
        cat > $out/share/applications/ghost-downloader.desktop << 'EOF'
  [Desktop Entry]
  Type=Application
  Name=Ghost Downloader
  Comment=Ghost Downloader 3 - Multi-threaded downloader
  Exec=ghost-downloader %u
  Icon=ghost-downloader
  Terminal=false
  Categories=Network;FileTransfer;
  EOF
      '';
      meta = with lib; {
        description = "Ghost Downloader 3 - multi-threaded downloader";
        platforms = platforms.linux;
      };
    };
in
{
  environment.systemPackages = with pkgs; [
    ffmpeg-full
    spectroterm
    ghost-downloader

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

  nixpkgs.overlays = with pkgs; [
    (self: super: {
      mpv-unwrapped = super.mpv-unwrapped.override {
        ffmpeg = ffmpeg-full;
      };
    })
    # nixpkgs 更新把 frei0r 包升到 3.2.1（CMake 构建），
    # 其 find_package(OpenCV) 在 CUDA 版 opencv 下硬性要求 CUDAToolkit/nvcc，
    # 导致构建失败（上游回归，release-25.11 仍为 2.5.1）。
    # 这里 pin 回 2.5.1（与 release-25.11 相同的表达式），
    # 与旧系统产物 drv 哈希一致，直接复用本地缓存，零编译。
    # 注意：ffmpeg-full 依赖的属性名是 frei0r（by-name 包），
    # frei0r-plugins 是别名，两个都覆盖以确保一致。
    (self: super: let
      frei0r-251 = super.stdenv.mkDerivation (finalAttrs: {
        pname = "frei0r-plugins";
        version = "2.5.1";
        src = super.fetchFromGitHub {
          owner = "dyne";
          repo = "frei0r";
          rev = "v${finalAttrs.version}";
          hash = "sha256-3gUWvO5izOrJt+XwcNBNiLfu+iMqo4nuPbx++TYzao0=";
        };
        nativeBuildInputs = [ super.cmake super.pkg-config ];
        buildInputs = [ super.cairo super.opencv ]
          ++ super.lib.optionals super.config.cudaSupport [
            super.cudaPackages.cuda_cudart
            super.cudaPackages.cuda_nvcc
          ];
        postInstall = super.lib.optionalString super.stdenv.hostPlatform.isDarwin ''
          for f in $out/lib/frei0r-1/*.so* ; do
            ln -s $f "''${f%.*}.dylib"
          done
        '';
        meta = {
          homepage = "https://frei0r.dyne.org";
          description = "Minimalist, cross-platform, shared video plugins";
          license = super.lib.licenses.gpl2Plus;
          platforms = super.lib.platforms.unix;
        };
      });
    in {
      frei0r = frei0r-251;
      frei0r-plugins = frei0r-251;
    })
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "ventoy-qt5-1.1.17"
  ];
}
