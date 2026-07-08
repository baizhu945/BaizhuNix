{ config, pkgs, lib, ... }:

let
  noctalia-v5 = pkgs.stdenv.mkDerivation {
    pname = "noctalia-v5";
    version = "5f636c6c";

    src = pkgs.fetchFromGitHub {
      owner = "noctalia-dev";
      repo = "noctalia";
      rev = "5f636c6cbed0ee6858fa6b83a9981a455c6d4d2c";
      sha256 = "sha256-3yP82Djjr//6Mn+Y0AYe/ywo7PpRCMpDqPxHrPqAWn0=";
    };
  
    nativeBuildInputs = with pkgs; [ meson ninja pkg-config wayland-scanner jemalloc ];
    buildInputs = with pkgs; [
      wayland wayland-protocols libGL libglvnd freetype fontconfig
      cairo pango harfbuzz libxkbcommon sdbus-cpp_2 systemd pipewire
      pam curl libwebp glib polkit librsvg libqalculate libxml2
    ];

    postPatch = ''
      sed -i "s/'-march=native', '-mtune=native',//" meson.build
    '';

    mesonBuildType = "release";
    ninjaFlags = [ "-v" ];

    meta = with lib; {
      description = "A sleek Wayland desktop shell for Niri and other compositors";
      homepage = "https://github.com/noctalia-dev/noctalia";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
      mainProgram = "noctalia";
    };
  };
in
{
  home.packages = [ noctalia-v5 ];
}
