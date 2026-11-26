{ pkgs, ... }:

let
  gopeed = pkgs.stdenvNoCC.mkDerivation (final: {
    pname = "gopeed";
    version = "2.0.0";

    src = pkgs.fetchurl {
      url = "https://github.com/GopeedLab/gopeed/releases/download/v${final.version}/Gopeed-v${final.version}-linux-amd64.deb";
      hash = "sha256-fOrYr6tPnOHOF1AvgzZUDIDiHp/yvAzUpAvys6E9FdE=";
    };

    nativeBuildInputs = with pkgs; [ binutils zstd autoPatchelfHook wrapGAppsHook3 ];
    buildInputs = with pkgs; [
      gtk3 webkitgtk_4_1 libayatana-appindicator libayatana-indicator
      ayatana-ido libdbusmenu-gtk3 libepoxy stdenv.cc.cc.lib
    ];

    dontUnpack = true;
    dontStrip = true;
    installPhase = ''
      runHook preInstall
      ar p "$src" data.tar.zst | tar --zstd -xf -
      mkdir -p "$out/libexec" "$out/bin"
      cp -r opt/gopeed "$out/libexec/"
      cp -r usr/share "$out/"
      ln -s "$out/libexec/gopeed/gopeed" "$out/bin/gopeed"
      runHook postInstall
    '';

    preFixup = ''
      addAutoPatchelfSearchPath "${pkgs.jre.home}/lib/server"
      # The Flutter frontend loads its Go backend dynamically.
      patchelf --add-needed libgopeed.so "$out/libexec/gopeed/gopeed"
    '';

    meta = {
      inherit (pkgs.gopeed.meta) description homepage license;
      mainProgram = "gopeed";
      platforms = [ "x86_64-linux" ];
    };
  });
in
{
  home.packages = [ gopeed ];
}
