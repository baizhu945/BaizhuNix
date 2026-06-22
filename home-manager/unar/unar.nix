{ config, lib, pkgs, ... }:

{
  home.file = {
    ".local/share/kio/servicemenus/unar-extract.desktop".text = ''
      [Desktop Entry]
      Type=Service
      ServiceTypes=KonqPopupMenu/Plugin
      MimeType=application/zip;application/x-zip;application/x-zip-compressed;application/x-7z-compressed;application/vnd.rar;application/x-rar;application/x-rar-compressed;application/x-tar;application/x-compressed-tar;application/gzip;application/x-gzip;application/x-bzip2;application/x-xz;application/zstd;application/x-zstd;application/x-xz-compressed-tar;application/x-bzip-compressed-tar;
      Actions=previewArchive;extractHere;

      [Desktop Action previewArchive]
      Name=使用 unar 预览
      Name[zh_CN]=使用 unar 预览
      Icon=archive-extract
      Exec=/home/<yourusername>/.local/bin/unar-preview.sh %f
      
      [Desktop Action extractHere]
      Name=使用 unar 解压
      Name[zh_CN]=使用 unar 解压
      Icon=archive-extract
      Exec=/home/<yourusername>/.local/bin/unar-extract.sh %f
    '';

    ".local/bin/unar-preview.py".source =
      ./unar-preview.py;

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
