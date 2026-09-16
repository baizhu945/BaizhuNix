{ config, lib, pkgs, ... }:

let
  homeBin = "${config.home.homeDirectory}/.local/bin";
  runtimePath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.kdePackages.kdialog
    pkgs.python3
    pkgs.unar
    pkgs.yad
  ];

  previewLauncher = pkgs.writeShellScript "unar-preview-launcher" ''
    export PATH="${runtimePath}:''${PATH:-}"
    exec "${homeBin}/unar-preview.sh" "$@"
  '';

  extractLauncher = pkgs.writeShellScript "unar-extract-launcher" ''
    export PATH="${runtimePath}:''${PATH:-}"
    exec "${homeBin}/unar-extract.sh" "$@"
  '';
in
{
  home.file = {
    ".local/share/kio/servicemenus/unar-extract.desktop" = {
      executable = true;
      text = ''
        [Desktop Entry]
        Type=Service
        Name=使用 unar
        Name[zh_CN]=使用 unar
        MimeType=application/zip;application/x-zip;application/x-zip-compressed;application/x-7z-compressed;application/vnd.rar;application/x-rar;application/x-rar-compressed;application/x-tar;application/x-compressed-tar;application/gzip;application/x-gzip;application/x-bzip2;application/x-xz;application/x-xz-compressed-tar;application/x-bzip-compressed-tar;application/x-cpio;application/x-lzma;
        X-KDE-Protocol=file
        X-KDE-RequiredNumberOfUrls=1
        Actions=previewArchive;extractHere;

        [Desktop Action previewArchive]
        Name=使用 unar 预览
        Name[zh_CN]=使用 unar 预览
        Icon=archive-extract
        Exec=${previewLauncher} %f

        [Desktop Action extractHere]
        Name=使用 unar 解压
        Name[zh_CN]=使用 unar 解压
        Icon=archive-extract
        Exec=${extractLauncher} %f
      '';
    };

    ".local/bin/unar-common.sh".source = ./unar-common.sh;

    ".local/bin/unar-preview.py" = {
      executable = true;
      source = ./unar-preview.py;
    };

    ".local/bin/unar-preview.sh" = {
      executable = true;
      source = ./unar-preview.sh;
    };

    ".local/bin/unar-extract.sh" = {
      executable = true;
      source = ./unar-extract.sh;
    };
  };
}
