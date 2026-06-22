{ config, pkgs, lib,  ... }:

let
  originalWallpaper =
    builtins.fetchurl "https://w.wallhaven.cc/full/d8/wallhaven-d8pyvo.jpg";

  # 在构建时用 ImageMagick 生成模糊版本
  # -blur 0x8 中，0 表示半径（自动），8 表示标准差（sigma），值越大越模糊
  blurredWallpaper = pkgs.runCommand "grub-blurred-wallpaper" {
    nativeBuildInputs = [ pkgs.imagemagick ];
  } ''
    mkdir -p $out
    # ImageMagick 的 convert 命令：先模糊，再输出为 PNG
    magick "${originalWallpaper}" -blur 20x16 $out/blurred.png
  '';
in
{
  # Bootloader.
  boot.loader = {
    grub = {
      gfxmodeEfi = "2560x1600";
      font = "${pkgs.nerd-fonts.noto}/share/fonts/truetype/NerdFonts/Noto/NotoSansMNerdFont-Bold.ttf";
      fontSize = 28;
      splashImage = "${blurredWallpaper}/blurred.png";
    };
  };
}
